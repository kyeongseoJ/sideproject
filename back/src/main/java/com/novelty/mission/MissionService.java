package com.novelty.mission;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.random.RandomGenerator;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

import com.novelty.user.UserService;

@Service
public class MissionService {

    private final UserService userService;
    private final MissionRepository missionRepository;
    private final MissionStatusLogRepository statusLogRepository;
    private final UserMissionRepository userMissionRepository;
    private final MissionRecommendationPolicy recommendationPolicy;
    private final TransactionTemplate transactionTemplate;
    private final Clock clock;
    private final RandomGenerator random;

    @Autowired
    public MissionService(
            UserService userService,
            MissionRepository missionRepository,
            MissionStatusLogRepository statusLogRepository,
            UserMissionRepository userMissionRepository,
            MissionRecommendationPolicy recommendationPolicy,
            TransactionTemplate transactionTemplate,
            Clock serviceClock) {
        this(
                userService,
                missionRepository,
                statusLogRepository,
                userMissionRepository,
                recommendationPolicy,
                transactionTemplate,
                serviceClock,
                new SecureRandom());
    }

    MissionService(
            UserService userService,
            MissionRepository missionRepository,
            MissionStatusLogRepository statusLogRepository,
            UserMissionRepository userMissionRepository,
            MissionRecommendationPolicy recommendationPolicy,
            TransactionTemplate transactionTemplate,
            Clock clock,
            RandomGenerator random) {
        this.userService = userService;
        this.missionRepository = missionRepository;
        this.statusLogRepository = statusLogRepository;
        this.userMissionRepository = userMissionRepository;
        this.recommendationPolicy = recommendationPolicy;
        this.transactionTemplate = transactionTemplate;
        this.clock = clock;
        this.random = random;
    }

    public MissionSettingsResponse getSettings(String userKey) {
        long userId = userService.requireUserId(userKey);
        return userMissionRepository.findSettings(userId)
                .orElseThrow(MissionSettingsRequiredException::new);
    }

    public MissionSettingsResponse saveSettings(
            String userKey,
            MissionSettingsRequest request) {
        if (request == null
                || request.availableTime() == null
                || request.dailyMissionLimit() < 1
                || request.dailyMissionLimit() > 3) {
            throw new InvalidMissionRequestException("사용 가능 시간과 하루 미션 수(1~3)를 확인해 주세요.");
        }
        long userId = userService.requireUserId(userKey);
        MissionSettingsResponse settings = new MissionSettingsResponse(
                request.availableTime(), request.dailyMissionLimit());
        return transactionTemplate.execute(status -> {
            userMissionRepository.lockUser(userId);
            int occupiedSlots = userMissionRepository.countOccupiedSlots(
                    userId, LocalDate.now(clock));
            if (settings.dailyMissionLimit() < occupiedSlots) {
                throw new DailyLimitReachedException();
            }
            return userMissionRepository.saveSettings(userId, settings);
        });
    }

    public MissionTodayResponse getToday(String userKey) {
        long userId = userService.requireUserId(userKey);
        MissionSettingsResponse settings = userMissionRepository.findSettings(userId)
                .orElseThrow(MissionSettingsRequiredException::new);
        return buildToday(userId, LocalDate.now(clock), settings);
    }

    public MissionRecommendationBatchResult recommendToday(String userKey) {
        long userId = userService.requireUserId(userKey);
        MissionRecommendationBatchResult result = transactionTemplate.execute(status -> {
            userMissionRepository.lockUser(userId);
            MissionSettingsResponse settings = userMissionRepository.findSettings(userId)
                    .orElseThrow(MissionSettingsRequiredException::new);
            LocalDate serviceDate = LocalDate.now(clock);
            if (!userMissionRepository.findToday(userId, serviceDate).isEmpty()) {
                return new MissionRecommendationBatchResult(
                        buildToday(userId, serviceDate, settings), false);
            }

            UserMissionVector vector = missionRepository.findUserVector(userId)
                    .orElseThrow(PersonalityRequiredException::new);
            List<Mission> candidates = missionRepository.findCandidates(
                    settings.availableTime().maximumMinutes(),
                    vector.completedMissionCount() >= 5);
            List<MissionRecommendation> recommendations = recommendationPolicy.recommend(
                    candidates,
                    vector,
                    settings.availableTime(),
                    userMissionRepository.findCategoryCompletionCounts(userId),
                    statusLogRepository.findAll(userId),
                    random);
            if (recommendations.isEmpty()) {
                throw new NoMissionAvailableException();
            }

            String offerBatchId = UUID.randomUUID().toString();
            OffsetDateTime shownAt = OffsetDateTime.now(clock);
            for (MissionRecommendation recommendation : recommendations) {
                long userMissionId = userMissionRepository.insertRecommendation(
                        userId,
                        serviceDate,
                        settings.availableTime(),
                        offerBatchId,
                        recommendation,
                        shownAt);
                Mission mission = recommendation.mission();
                statusLogRepository.append(
                        userId, mission.id(), userMissionId, mission.category().name(),
                        null, MissionStatus.GENERATED, "DAILY_RECOMMENDATION", shownAt);
                statusLogRepository.append(
                        userId, mission.id(), userMissionId, mission.category().name(),
                        MissionStatus.GENERATED, MissionStatus.SHOWN,
                        "DAILY_RECOMMENDATION", shownAt);
            }
            return new MissionRecommendationBatchResult(
                    buildToday(userId, serviceDate, settings), true);
        });
        if (result == null) {
            throw new IllegalStateException("Mission recommendation transaction returned no result.");
        }
        return result;
    }

    MissionTodayResponse buildToday(
            long userId,
            LocalDate serviceDate,
            MissionSettingsResponse settings) {
        List<UserMissionResponse> today = userMissionRepository.findToday(userId, serviceDate);
        int completedToday = (int) today.stream()
                .filter(mission -> mission.status() == MissionStatus.COMPLETED)
                .count();
        int occupiedSlots = (int) today.stream()
                .filter(mission -> mission.status() == MissionStatus.SELECTED
                        || mission.status() == MissionStatus.COMPLETED)
                .count();
        List<UserMissionResponse> active = today.stream()
                .filter(mission -> mission.status() == MissionStatus.SELECTED)
                .toList();
        List<UserMissionResponse> candidates = today.stream()
                .filter(mission -> mission.status() == MissionStatus.SHOWN
                        || mission.status() == MissionStatus.CANCELLED)
                .toList();
        return new MissionTodayResponse(
                serviceDate,
                settings,
                completedToday,
                Math.max(0, settings.dailyMissionLimit() - occupiedSlots),
                active,
                candidates);
    }

}
