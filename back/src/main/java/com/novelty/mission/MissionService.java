package com.novelty.mission;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;
import java.util.random.RandomGenerator;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

import com.novelty.user.UserService;

@Service
public class MissionService {

    private static final int DAILY_MISSION_LIMIT = 1;
    private static final int MAX_MISSION_MINUTES = 180;

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

    public MissionTodayResponse getToday(String userKey) {
        long userId = userService.requireUserId(userKey);
        return buildToday(userId, LocalDate.now(clock));
    }

    public MissionRecommendationBatchResult recommendToday(String userKey) {
        long userId = userService.requireUserId(userKey);
        MissionRecommendationBatchResult result = transactionTemplate.execute(status -> {
            userMissionRepository.lockUser(userId);
            LocalDate serviceDate = LocalDate.now(clock);
            if (!userMissionRepository.findToday(userId, serviceDate).isEmpty()) {
                return new MissionRecommendationBatchResult(
                        buildToday(userId, serviceDate), false);
            }

            UserMissionVector vector = missionRepository.findUserVector(userId)
                    .orElseThrow(PersonalityRequiredException::new);
            List<Mission> candidates = missionRepository.findCandidates(
                    MAX_MISSION_MINUTES,
                    vector.completedMissionCount() >= 5);
            List<MissionRecommendation> recommendations = recommendationPolicy.recommend(
                    candidates,
                    vector,
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
                    buildToday(userId, serviceDate), true);
        });
        if (result == null) {
            throw new IllegalStateException("Mission recommendation transaction returned no result.");
        }
        return result;
    }

    MissionTodayResponse buildToday(long userId, LocalDate serviceDate) {
        List<UserMissionResponse> today = userMissionRepository.findToday(userId, serviceDate);
        int completedToday = (int) today.stream()
                .filter(mission -> mission.status() == MissionStatus.COMPLETED)
                .count();
        List<UserMissionResponse> active = today.stream()
                .filter(mission -> mission.status() == MissionStatus.SELECTED)
                .toList();
        List<UserMissionResponse> candidates = today.stream()
                .filter(mission -> mission.status() == MissionStatus.SHOWN
                        || mission.status() == MissionStatus.CANCELLED)
                .toList();
        return new MissionTodayResponse(serviceDate, completedToday, active, candidates);
    }

    static int dailyMissionLimit() {
        return DAILY_MISSION_LIMIT;
    }
}
