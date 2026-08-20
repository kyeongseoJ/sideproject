package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.TransactionStatus;
import org.springframework.transaction.support.TransactionCallback;
import org.springframework.transaction.support.TransactionTemplate;

import com.novelty.user.UserService;

class MissionPhase5ServiceTest {

    private static final String USER_KEY = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    private static final long USER_ID = 7L;
    private static final long USER_MISSION_ID = 101L;
    private static final LocalDate TODAY = LocalDate.of(2026, 8, 20);
    private static final MissionSettingsResponse SETTINGS =
            new MissionSettingsResponse(AvailableTime.SHORT, 1);

    private UserService userService;
    private UserMissionRepository userMissionRepository;
    private MissionStatusLogRepository statusLogRepository;
    private MissionService missionService;
    private MissionCompletionRepository completionRepository;
    private MissionProfileUpdater profileUpdater;
    private MissionLlmGenerationService llmGenerationService;
    private UserMissionService service;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        userService = mock(UserService.class);
        userMissionRepository = mock(UserMissionRepository.class);
        statusLogRepository = mock(MissionStatusLogRepository.class);
        missionService = mock(MissionService.class);
        completionRepository = mock(MissionCompletionRepository.class);
        profileUpdater = mock(MissionProfileUpdater.class);
        llmGenerationService = mock(MissionLlmGenerationService.class);
        TransactionTemplate transactionTemplate = mock(TransactionTemplate.class);
        when(transactionTemplate.execute(any())).thenAnswer(invocation -> {
            TransactionCallback<?> callback = invocation.getArgument(0);
            return callback.doInTransaction(mock(TransactionStatus.class));
        });
        when(userService.requireUserId(USER_KEY)).thenReturn(USER_ID);
        when(userMissionRepository.findSettingsForUpdate(USER_ID))
                .thenReturn(Optional.of(SETTINGS));
        when(userMissionRepository.findOwnedForUpdate(USER_ID, USER_MISSION_ID))
                .thenReturn(Optional.of(state(MissionStatus.SELECTED)));
        when(userMissionRepository.findOwned(USER_ID, USER_MISSION_ID))
                .thenReturn(Optional.of(response(MissionStatus.COMPLETED)));
        when(missionService.buildToday(USER_ID, TODAY, SETTINGS)).thenReturn(today());
        service = new UserMissionService(
                userService,
                userMissionRepository,
                statusLogRepository,
                missionService,
                completionRepository,
                profileUpdater,
                llmGenerationService,
                transactionTemplate,
                Clock.fixed(Instant.parse("2026-08-20T00:00:00Z"), ZoneId.of("Asia/Seoul")));
    }

    @Test
    void completionAtomicallyUpdatesCategoryAndCompletionCount() {
        UserMissionVector vector = new UserMissionVector(-1, -1, 0, 1, 1);
        when(profileUpdater.recordCompletion(USER_ID)).thenReturn(
                new MissionProfileUpdater.CompletionUpdate(vector, false, 0, null));
        when(completionRepository.findSummary(USER_ID)).thenReturn(summary(1, 0));

        UserMissionActionResponse result = service.complete(USER_KEY, USER_MISSION_ID);

        assertThat(result.completion().summary().completedMissionCount()).isEqualTo(1);
        assertThat(result.completion().personalityUpdated()).isFalse();
        assertThat(result.completion().llmGenerationStatus()).isEqualTo("NOT_DUE");
        verify(completionRepository).incrementCategory(eq(USER_ID), eq(MissionCategory.MOVEMENT), any());
        verify(profileUpdater).recordCompletion(USER_ID);
        verify(llmGenerationService, never()).generateAtMilestone(
                eq(USER_ID), eq(5), any());
    }

    @Test
    void fifthCompletionUpdatesPersonalityAndTriggersLlmAfterTransaction() {
        UserMissionVector vector = new UserMissionVector(0, 0, 1, 1, 5);
        when(profileUpdater.recordCompletion(USER_ID)).thenReturn(
                new MissionProfileUpdater.CompletionUpdate(
                        vector, true, 5, "BALANCED_COORDINATOR"));
        when(completionRepository.findSummary(USER_ID)).thenReturn(summary(5, 5));
        when(llmGenerationService.generateAtMilestone(USER_ID, 5, vector))
                .thenReturn("CREATED");

        UserMissionActionResponse result = service.complete(USER_KEY, USER_MISSION_ID);

        assertThat(result.completion().personalityUpdated()).isTrue();
        assertThat(result.completion().milestone()).isEqualTo(5);
        assertThat(result.completion().llmGenerationStatus()).isEqualTo("CREATED");
        assertThat(result.completion().summary().lastPersonalityAdaptedCount()).isEqualTo(5);
        verify(llmGenerationService).generateAtMilestone(USER_ID, 5, vector);
    }

    @Test
    void llmFailureIsIsolatedFromCommittedCompletionResponse() {
        UserMissionVector vector = new UserMissionVector(0, 0, 1, 1, 5);
        when(profileUpdater.recordCompletion(USER_ID)).thenReturn(
                new MissionProfileUpdater.CompletionUpdate(
                        vector, true, 5, "BALANCED_COORDINATOR"));
        when(completionRepository.findSummary(USER_ID)).thenReturn(summary(5, 5));
        when(llmGenerationService.generateAtMilestone(USER_ID, 5, vector))
                .thenThrow(new IllegalStateException("external failure"));

        UserMissionActionResponse result = service.complete(USER_KEY, USER_MISSION_ID);

        assertThat(result.mission().status()).isEqualTo(MissionStatus.COMPLETED);
        assertThat(result.completion().llmGenerationStatus()).isEqualTo("FAILED");
    }

    @Test
    void completionRetryDoesNotIncrementStatsOrTriggerLlmAgain() {
        when(userMissionRepository.findOwnedForUpdate(USER_ID, USER_MISSION_ID))
                .thenReturn(Optional.of(state(MissionStatus.COMPLETED)));
        when(completionRepository.findSummary(USER_ID)).thenReturn(summary(5, 5));

        UserMissionActionResponse result = service.complete(USER_KEY, USER_MISSION_ID);

        assertThat(result.idempotent()).isTrue();
        assertThat(result.completion().summary().completedMissionCount()).isEqualTo(5);
        verify(completionRepository, never()).incrementCategory(any(Long.class), any(), any());
        verify(profileUpdater, never()).recordCompletion(USER_ID);
        verify(llmGenerationService, never()).generateAtMilestone(eq(USER_ID), eq(5), any());
    }

    @Test
    void profileUpdateFailureAbortsCompletionFlow() {
        when(profileUpdater.recordCompletion(USER_ID))
                .thenThrow(new IllegalStateException("profile update failed"));

        assertThatThrownBy(() -> service.complete(USER_KEY, USER_MISSION_ID))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("profile update failed");
        verify(llmGenerationService, never()).generateAtMilestone(eq(USER_ID), eq(5), any());
    }

    @Test
    void summaryUsesAuthenticatedUserScope() {
        MissionSummaryResponse expected = summary(7, 5);
        when(completionRepository.findSummary(USER_ID)).thenReturn(expected);

        assertThat(service.getSummary(USER_KEY)).isEqualTo(expected);
        verify(userService).requireUserId(USER_KEY);
    }

    private UserMissionState state(MissionStatus status) {
        return new UserMissionState(
                USER_MISSION_ID, 1L, MissionCategory.MOVEMENT,
                status, TODAY, 1);
    }

    private UserMissionResponse response(MissionStatus status) {
        return new UserMissionResponse(
                USER_MISSION_ID, 1L, "미션", "설명", MissionCategory.MOVEMENT,
                1, 5, 1, 1, 2, 2, MissionSourceType.BASE,
                0.8, 0.8, status, OffsetDateTime.parse("2026-08-20T09:00:00+09:00"));
    }

    private MissionTodayResponse today() {
        return new MissionTodayResponse(TODAY, SETTINGS, 1, 0, List.of(), List.of());
    }

    private MissionSummaryResponse summary(int completedCount, int adaptedCount) {
        return new MissionSummaryResponse(
                completedCount,
                adaptedCount,
                adaptedCount == 0 ? "QUIET_FOCUSER" : "BALANCED_COORDINATOR",
                List.of(new MissionCategoryStatResponse(
                        MissionCategory.MOVEMENT,
                        completedCount,
                        OffsetDateTime.parse("2026-08-20T09:00:00+09:00"))));
    }
}
