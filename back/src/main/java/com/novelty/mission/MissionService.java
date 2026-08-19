package com.novelty.mission;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Set;
import java.util.random.RandomGenerator;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

import com.novelty.user.UserService;

@Service
public class MissionService {

    private static final int RANDOM_POOL_SIZE = 3;

    private final UserService userService;
    private final MissionRepository missionRepository;
    private final MissionStatusLogRepository statusLogRepository;
    private final MissionRecommendationPolicy recommendationPolicy;
    private final MissionProfileUpdater profileUpdater;
    private final MissionLlmGenerationService llmGenerationService;
    private final TransactionTemplate transactionTemplate;
    private final Clock clock;
    private final RandomGenerator random;

    @Autowired
    public MissionService(
            UserService userService,
            MissionRepository missionRepository,
            MissionStatusLogRepository statusLogRepository,
            MissionRecommendationPolicy recommendationPolicy,
            MissionProfileUpdater profileUpdater,
            MissionLlmGenerationService llmGenerationService,
            TransactionTemplate transactionTemplate,
            Clock serviceClock) {
        this(
                userService,
                missionRepository,
                statusLogRepository,
                recommendationPolicy,
                profileUpdater,
                llmGenerationService,
                transactionTemplate,
                serviceClock,
                new SecureRandom());
    }

    MissionService(
            UserService userService,
            MissionRepository missionRepository,
            MissionStatusLogRepository statusLogRepository,
            MissionRecommendationPolicy recommendationPolicy,
            MissionProfileUpdater profileUpdater,
            MissionLlmGenerationService llmGenerationService,
            TransactionTemplate transactionTemplate,
            Clock clock,
            RandomGenerator random) {
        this.userService = userService;
        this.missionRepository = missionRepository;
        this.statusLogRepository = statusLogRepository;
        this.recommendationPolicy = recommendationPolicy;
        this.profileUpdater = profileUpdater;
        this.llmGenerationService = llmGenerationService;
        this.transactionTemplate = transactionTemplate;
        this.clock = clock;
        this.random = random;
    }

    public MissionResponse recommend(String userKey, MissionRecommendationRequest request) {
        if (request == null || request.availableTime() == null) {
            throw new InvalidMissionRequestException("오늘 미션에 사용할 시간을 선택해 주세요.");
        }
        long userId = userService.requireUserId(userKey);
        UserMissionVector vector = missionRepository.findUserVector(userId)
                .orElseThrow(PersonalityRequiredException::new);
        List<Mission> candidates = missionRepository.findCandidates(
                request.availableTime().maximumMinutes(),
                vector.completedMissionCount() >= 5);
        List<MissionCandidate> eligibleReferences = recommendationPolicy.filterEligible(
                candidates.stream().map(Mission::candidate).toList(),
                statusLogRepository.findAll(userId));
        Set<Long> eligibleIds = eligibleReferences.stream()
                .map(MissionCandidate::missionId)
                .collect(java.util.stream.Collectors.toSet());
        List<Mission> ranked = candidates.stream()
                .filter(mission -> eligibleIds.contains(mission.id()))
                .sorted(Comparator.comparingDouble(
                        (Mission mission) -> vector.distanceFrom(mission)).reversed())
                .toList();
        if (ranked.isEmpty()) {
            throw new NoMissionAvailableException();
        }

        int poolSize = Math.min(RANDOM_POOL_SIZE, ranked.size());
        Mission selected = ranked.get(random.nextInt(poolSize));
        double distance = vector.distanceFrom(selected);
        transactionTemplate.executeWithoutResult(status -> {
            OffsetDateTime occurredAt = OffsetDateTime.now(clock);
            statusLogRepository.append(
                    userId, selected.id(), selected.category().name(), MissionStatus.GENERATED, occurredAt);
            statusLogRepository.append(
                    userId, selected.id(), selected.category().name(), MissionStatus.SHOWN, occurredAt);
        });
        return MissionResponse.shown(selected, distance);
    }

    public MissionStatusResponse changeStatus(
            String userKey,
            long missionId,
            MissionStatusRequest request) {
        if (request == null || request.status() == null) {
            throw new InvalidMissionRequestException("변경할 미션 상태가 필요합니다.");
        }
        if (request.status() != MissionStatus.SELECTED
                && request.status() != MissionStatus.CANCELLED
                && request.status() != MissionStatus.COMPLETED) {
            throw new InvalidMissionRequestException("사용자가 변경할 수 없는 미션 상태입니다.");
        }

        long userId = userService.requireUserId(userKey);
        CompletionTransactionResult result = transactionTemplate.execute(status -> {
            Mission mission = missionRepository.findById(missionId)
                    .orElseThrow(MissionNotFoundException::new);
            MissionStatus previous = statusLogRepository.findLatestStatus(userId, missionId)
                    .orElseThrow(InvalidMissionTransitionException::new);
            validateTransition(previous, request.status());
            statusLogRepository.append(
                    userId,
                    mission.id(),
                    mission.category().name(),
                    request.status(),
                    OffsetDateTime.now(clock));

            if (request.status() == MissionStatus.COMPLETED) {
                MissionProfileUpdater.CompletionUpdate update = profileUpdater.recordCompletion(userId);
                return new CompletionTransactionResult(
                        update.vector(), update.personalityUpdated(), update.milestone());
            }
            UserMissionVector vector = missionRepository.findUserVector(userId)
                    .orElseThrow(PersonalityRequiredException::new);
            return new CompletionTransactionResult(vector, false, 0);
        });
        if (result == null) {
            throw new IllegalStateException("Mission status transaction returned no result.");
        }

        String generationStatus = result.milestone() > 0
                ? llmGenerationService.generateAtMilestone(
                        userId, result.milestone(), result.vector())
                : "NOT_DUE";
        return new MissionStatusResponse(
                missionId,
                request.status().name(),
                displayStatus(request.status()),
                result.vector().completedMissionCount(),
                result.personalityUpdated(),
                generationStatus);
    }

    private void validateTransition(MissionStatus previous, MissionStatus requested) {
        boolean valid = requested == MissionStatus.SELECTED && previous == MissionStatus.SHOWN
                || requested == MissionStatus.CANCELLED && previous == MissionStatus.SELECTED
                || requested == MissionStatus.COMPLETED && previous == MissionStatus.SELECTED;
        if (!valid) {
            throw new InvalidMissionTransitionException();
        }
    }

    private String displayStatus(MissionStatus status) {
        return switch (status) {
            case SELECTED -> "수행중";
            case COMPLETED -> "완료";
            case CANCELLED -> "취소";
            default -> null;
        };
    }

    private record CompletionTransactionResult(
            UserMissionVector vector,
            boolean personalityUpdated,
            int milestone) {
    }
}
