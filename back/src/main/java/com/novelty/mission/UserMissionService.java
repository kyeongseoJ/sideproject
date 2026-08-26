package com.novelty.mission;

import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

import com.novelty.user.UserService;
import com.novelty.world.WorldGrowthResponse;
import com.novelty.world.WorldProgressService;

@Service
public class UserMissionService {

    private final UserService userService;
    private final UserMissionRepository userMissionRepository;
    private final MissionStatusLogRepository statusLogRepository;
    private final MissionService missionService;
    private final MissionCompletionRepository completionRepository;
    private final MissionProfileUpdater profileUpdater;
    private final MissionLlmGenerationService llmGenerationService;
    private final WorldProgressService worldProgressService;
    private final TransactionTemplate transactionTemplate;
    private final Clock clock;

    public UserMissionService(
            UserService userService,
            UserMissionRepository userMissionRepository,
            MissionStatusLogRepository statusLogRepository,
            MissionService missionService,
            MissionCompletionRepository completionRepository,
            MissionProfileUpdater profileUpdater,
            MissionLlmGenerationService llmGenerationService,
            WorldProgressService worldProgressService,
            TransactionTemplate transactionTemplate,
            Clock serviceClock) {
        this.userService = userService;
        this.userMissionRepository = userMissionRepository;
        this.statusLogRepository = statusLogRepository;
        this.missionService = missionService;
        this.completionRepository = completionRepository;
        this.profileUpdater = profileUpdater;
        this.llmGenerationService = llmGenerationService;
        this.worldProgressService = worldProgressService;
        this.transactionTemplate = transactionTemplate;
        this.clock = serviceClock;
    }

    public UserMissionActionResponse select(String userKey, long userMissionId) {
        requirePositiveId(userMissionId);
        long userId = userService.requireUserId(userKey);
        return requireResult(transactionTemplate.execute(status -> {
            LockedContext context = lockContext(userId);
            UserMissionState target = requireOwned(userId, userMissionId);
            requireToday(target, context.serviceDate());
            if (target.status() != MissionStatus.SHOWN
                    && target.status() != MissionStatus.CANCELLED) {
                throw new InvalidMissionTransitionException();
            }
            if (userMissionRepository.countOccupiedSlots(userId, context.serviceDate())
                    >= MissionService.dailyMissionLimit()) {
                throw new DailyLimitReachedException();
            }
            int slot = userMissionRepository.firstAvailableSlot(
                    userId, context.serviceDate(), MissionService.dailyMissionLimit());
            OffsetDateTime occurredAt = OffsetDateTime.now(clock);
            userMissionRepository.markSelected(userMissionId, slot, occurredAt);
            appendLog(userId, target, MissionStatus.SELECTED, "USER_SELECTED", occurredAt);
            return actionResponse(userId, userMissionId, context, false);
        }));
    }

    public UserMissionActionResponse cancel(String userKey, long userMissionId) {
        requirePositiveId(userMissionId);
        long userId = userService.requireUserId(userKey);
        return requireResult(transactionTemplate.execute(status -> {
            LockedContext context = lockContext(userId);
            UserMissionState target = requireOwned(userId, userMissionId);
            requireToday(target, context.serviceDate());
            if (target.status() != MissionStatus.SELECTED) {
                throw new InvalidMissionTransitionException();
            }
            OffsetDateTime occurredAt = OffsetDateTime.now(clock);
            userMissionRepository.markCancelled(userMissionId, occurredAt);
            appendLog(userId, target, MissionStatus.CANCELLED, "USER_CANCELLED", occurredAt);
            return actionResponse(userId, userMissionId, context, false);
        }));
    }

    public UserMissionActionResponse replace(
            String userKey,
            long userMissionId,
            ReplacementMissionRequest request) {
        requirePositiveId(userMissionId);
        if (request == null
                || request.replacementUserMissionId() <= 0
                || request.replacementUserMissionId() == userMissionId) {
            throw new InvalidMissionRequestException("교체할 다른 추천 후보가 필요합니다.");
        }
        long replacementId = request.replacementUserMissionId();
        long userId = userService.requireUserId(userKey);
        return requireResult(transactionTemplate.execute(status -> {
            LockedContext context = lockContext(userId);
            List<UserMissionState> locked = userMissionRepository.findOwnedPairForUpdate(
                    userId, userMissionId, replacementId);
            if (locked.size() != 2) {
                throw new UserMissionNotFoundException();
            }
            UserMissionState current = locked.stream()
                    .filter(item -> item.userMissionId() == userMissionId)
                    .findFirst()
                    .orElseThrow(UserMissionNotFoundException::new);
            UserMissionState replacement = locked.stream()
                    .filter(item -> item.userMissionId() == replacementId)
                    .findFirst()
                    .orElseThrow(UserMissionNotFoundException::new);
            requireToday(current, context.serviceDate());
            if (current.status() != MissionStatus.SELECTED || current.dailySlotNo() == null) {
                throw new InvalidMissionTransitionException();
            }
            if (!replacement.serviceDate().equals(context.serviceDate())
                    || (replacement.status() != MissionStatus.SHOWN
                            && replacement.status() != MissionStatus.CANCELLED)) {
                throw new ReplacementNotAvailableException();
            }

            OffsetDateTime occurredAt = OffsetDateTime.now(clock);
            userMissionRepository.markCancelled(userMissionId, occurredAt);
            userMissionRepository.markSelected(
                    replacementId, current.dailySlotNo(), occurredAt);
            appendLog(userId, current, MissionStatus.CANCELLED, "USER_REPLACED", occurredAt);
            appendLog(userId, replacement, MissionStatus.SELECTED, "REPLACEMENT_SELECTED", occurredAt);
            return actionResponse(userId, replacementId, context, false);
        }));
    }

    public UserMissionActionResponse complete(String userKey, long userMissionId) {
        requirePositiveId(userMissionId);
        long userId = userService.requireUserId(userKey);
        CompletionTransactionResult result = requireCompletionResult(transactionTemplate.execute(status -> {
            LockedContext context = lockContext(userId);
            UserMissionState target = requireOwned(userId, userMissionId);
            if (target.status() == MissionStatus.COMPLETED) {
                WorldGrowthResponse worldGrowth = worldProgressService.currentWithoutReward(
                        userId, target.category());
                MissionCompletionEffectResponse effect = new MissionCompletionEffectResponse(
                        completionRepository.findSummary(userId), false, null, 0, "NOT_DUE", worldGrowth);
                return new CompletionTransactionResult(
                        actionResponse(userId, userMissionId, context, true, effect), null);
            }
            requireToday(target, context.serviceDate());
            if (target.status() != MissionStatus.SELECTED || target.dailySlotNo() == null) {
                throw new InvalidMissionTransitionException();
            }
            OffsetDateTime occurredAt = OffsetDateTime.now(clock);
            userMissionRepository.markCompleted(userMissionId, occurredAt);
            appendLog(userId, target, MissionStatus.COMPLETED, "USER_COMPLETED", occurredAt);
            completionRepository.incrementCategory(userId, target.category(), occurredAt);
            MissionProfileUpdater.CompletionUpdate update = profileUpdater.recordCompletion(
                    userId, target.missionId());
            WorldGrowthResponse worldGrowth = worldProgressService.applyMissionCompletion(
                    userId, target.category(), target.difficulty());
            MissionCompletionEffectResponse effect = new MissionCompletionEffectResponse(
                    completionRepository.findSummary(userId),
                    update.personalityUpdated(),
                    MissionPersonalityChangeResponse.from(update),
                    update.milestone(),
                    "NOT_DUE",
                    worldGrowth);
            return new CompletionTransactionResult(
                    actionResponse(userId, userMissionId, context, false, effect), update);
        }));

        MissionProfileUpdater.CompletionUpdate update = result.update();
        if (update == null || update.milestone() == 0) {
            return result.response();
        }
        String generationStatus;
        try {
            generationStatus = llmGenerationService.generateAtMilestone(
                    userId, update.milestone(), update.vector());
        } catch (RuntimeException exception) {
            generationStatus = "FAILED";
        }
        MissionCompletionEffectResponse current = result.response().completion();
        MissionCompletionEffectResponse completedEffect = new MissionCompletionEffectResponse(
                current.summary(),
                current.personalityUpdated(),
                current.personalityChange(),
                current.milestone(),
                generationStatus,
                current.worldGrowth());
        return new UserMissionActionResponse(
                result.response().mission(),
                result.response().today(),
                result.response().idempotent(),
                completedEffect);
    }

    public MissionSummaryResponse getSummary(String userKey) {
        long userId = userService.requireUserId(userKey);
        return completionRepository.findSummary(userId);
    }

    private LockedContext lockContext(long userId) {
        userMissionRepository.lockUser(userId);
        return new LockedContext(LocalDate.now(clock));
    }

    private UserMissionState requireOwned(long userId, long userMissionId) {
        return userMissionRepository.findOwnedForUpdate(userId, userMissionId)
                .orElseThrow(UserMissionNotFoundException::new);
    }

    private void requireToday(UserMissionState target, LocalDate serviceDate) {
        if (!target.serviceDate().equals(serviceDate)) {
            throw new InvalidMissionTransitionException();
        }
    }

    private void appendLog(
            long userId,
            UserMissionState target,
            MissionStatus requested,
            String reason,
            OffsetDateTime occurredAt) {
        statusLogRepository.append(
                userId,
                target.missionId(),
                target.userMissionId(),
                target.category().name(),
                target.status(),
                requested,
                reason,
                occurredAt);
    }

    private UserMissionActionResponse actionResponse(
            long userId,
            long userMissionId,
            LockedContext context,
            boolean idempotent) {
        return actionResponse(userId, userMissionId, context, idempotent, null);
    }

    private UserMissionActionResponse actionResponse(
            long userId,
            long userMissionId,
            LockedContext context,
            boolean idempotent,
            MissionCompletionEffectResponse completion) {
        UserMissionResponse mission = userMissionRepository.findOwned(userId, userMissionId)
                .orElseThrow(UserMissionNotFoundException::new);
        return new UserMissionActionResponse(
                mission,
                missionService.buildToday(userId, context.serviceDate()),
                idempotent,
                completion);
    }

    private UserMissionActionResponse requireResult(UserMissionActionResponse result) {
        if (result == null) {
            throw new IllegalStateException("User mission transaction returned no result.");
        }
        return result;
    }

    private CompletionTransactionResult requireCompletionResult(CompletionTransactionResult result) {
        if (result == null) {
            throw new IllegalStateException("Mission completion transaction returned no result.");
        }
        return result;
    }

    private void requirePositiveId(long userMissionId) {
        if (userMissionId <= 0) {
            throw new InvalidMissionRequestException("올바른 사용자 미션 ID가 필요합니다.");
        }
    }

    private record LockedContext(LocalDate serviceDate) {
    }

    private record CompletionTransactionResult(
            UserMissionActionResponse response,
            MissionProfileUpdater.CompletionUpdate update) {
    }
}
