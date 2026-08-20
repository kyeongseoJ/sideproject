package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
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

class MissionPhase4ServiceTest {

    private static final String USER_KEY = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    private static final long USER_ID = 7L;
    private static final LocalDate TODAY = LocalDate.of(2026, 8, 20);
    private static final MissionSettingsResponse SETTINGS =
            new MissionSettingsResponse(AvailableTime.SHORT, 2);

    private UserService userService;
    private UserMissionRepository repository;
    private MissionStatusLogRepository logRepository;
    private MissionService missionService;
    private MissionCompletionRepository completionRepository;
    private MissionProfileUpdater profileUpdater;
    private MissionLlmGenerationService llmGenerationService;
    private UserMissionService service;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        userService = mock(UserService.class);
        repository = mock(UserMissionRepository.class);
        logRepository = mock(MissionStatusLogRepository.class);
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
        when(repository.findSettingsForUpdate(USER_ID)).thenReturn(Optional.of(SETTINGS));
        when(missionService.buildToday(USER_ID, TODAY, SETTINGS)).thenReturn(today());
        service = new UserMissionService(
                userService,
                repository,
                logRepository,
                missionService,
                completionRepository,
                profileUpdater,
                llmGenerationService,
                transactionTemplate,
                Clock.fixed(Instant.parse("2026-08-20T00:00:00Z"), ZoneId.of("Asia/Seoul")));
    }

    @Test
    void selectsShownOrCancelledCandidateIntoFirstAvailableSlot() {
        UserMissionState target = state(101, MissionStatus.SHOWN, null);
        when(repository.findOwnedForUpdate(USER_ID, 101)).thenReturn(Optional.of(target));
        when(repository.countOccupiedSlots(USER_ID, TODAY)).thenReturn(1);
        when(repository.firstAvailableSlot(USER_ID, TODAY, 2)).thenReturn(2);
        when(repository.findOwned(USER_ID, 101)).thenReturn(Optional.of(response(101, MissionStatus.SELECTED)));

        UserMissionActionResponse result = service.select(USER_KEY, 101);

        assertThat(result.mission().status()).isEqualTo(MissionStatus.SELECTED);
        verify(repository).markSelected(eq(101L), eq(2), any());
        verify(logRepository).append(
                eq(USER_ID), eq(1L), eq(101L), eq("MOVEMENT"),
                eq(MissionStatus.SHOWN), eq(MissionStatus.SELECTED),
                eq("USER_SELECTED"), any());
    }

    @Test
    void rejectsSelectionWhenDailyLimitIsReached() {
        when(repository.findOwnedForUpdate(USER_ID, 101))
                .thenReturn(Optional.of(state(101, MissionStatus.SHOWN, null)));
        when(repository.countOccupiedSlots(USER_ID, TODAY)).thenReturn(2);

        assertThatThrownBy(() -> service.select(USER_KEY, 101))
                .isInstanceOf(DailyLimitReachedException.class);
        verify(repository, never()).markSelected(anyLong(), anyInt(), any());
    }

    @Test
    void cancelsOnlySelectedMissionAndReleasesItsSlot() {
        UserMissionState selected = state(101, MissionStatus.SELECTED, 1);
        when(repository.findOwnedForUpdate(USER_ID, 101)).thenReturn(Optional.of(selected));
        when(repository.findOwned(USER_ID, 101)).thenReturn(Optional.of(response(101, MissionStatus.CANCELLED)));

        assertThat(service.cancel(USER_KEY, 101).mission().status())
                .isEqualTo(MissionStatus.CANCELLED);
        verify(repository).markCancelled(eq(101L), any());

        when(repository.findOwnedForUpdate(USER_ID, 102))
                .thenReturn(Optional.of(state(102, MissionStatus.SHOWN, null)));
        assertThatThrownBy(() -> service.cancel(USER_KEY, 102))
                .isInstanceOf(InvalidMissionTransitionException.class);
    }

    @Test
    void atomicallyReplacesSelectedMissionWithTodayCandidate() {
        UserMissionState current = state(101, MissionStatus.SELECTED, 2);
        UserMissionState replacement = state(102, MissionStatus.CANCELLED, null);
        when(repository.findOwnedPairForUpdate(USER_ID, 101, 102))
                .thenReturn(List.of(current, replacement));
        when(repository.findOwned(USER_ID, 102))
                .thenReturn(Optional.of(response(102, MissionStatus.SELECTED)));

        UserMissionActionResponse result = service.replace(
                USER_KEY, 101, new ReplacementMissionRequest(102));

        assertThat(result.mission().userMissionId()).isEqualTo(102);
        verify(repository).markCancelled(eq(101L), any());
        verify(repository).markSelected(eq(102L), eq(2), any());
    }

    @Test
    void rejectsUnavailableReplacementAndOwnershipMismatch() {
        UserMissionState current = state(101, MissionStatus.SELECTED, 1);
        UserMissionState completed = state(102, MissionStatus.COMPLETED, 2);
        when(repository.findOwnedPairForUpdate(USER_ID, 101, 102))
                .thenReturn(List.of(current, completed));
        assertThatThrownBy(() -> service.replace(
                        USER_KEY, 101, new ReplacementMissionRequest(102)))
                .isInstanceOf(ReplacementNotAvailableException.class);

        when(repository.findOwnedPairForUpdate(USER_ID, 101, 999))
                .thenReturn(List.of(current));
        assertThatThrownBy(() -> service.replace(
                        USER_KEY, 101, new ReplacementMissionRequest(999)))
                .isInstanceOf(UserMissionNotFoundException.class);
    }

    @Test
    void completesOnceAndReturnsIdempotentResultForRetry() {
        UserMissionState selected = state(101, MissionStatus.SELECTED, 1);
        when(repository.findOwnedForUpdate(USER_ID, 101)).thenReturn(Optional.of(selected));
        when(repository.findOwned(USER_ID, 101)).thenReturn(Optional.of(response(101, MissionStatus.COMPLETED)));
        when(profileUpdater.recordCompletion(USER_ID)).thenReturn(
                new MissionProfileUpdater.CompletionUpdate(
                        new UserMissionVector(-1, -1, 0, 1, 1), false, 0, null));
        when(completionRepository.findSummary(USER_ID)).thenReturn(summary(1));

        UserMissionActionResponse first = service.complete(USER_KEY, 101);
        assertThat(first.idempotent()).isFalse();
        verify(repository).markCompleted(eq(101L), any());

        UserMissionState completed = state(101, MissionStatus.COMPLETED, 1);
        when(repository.findOwnedForUpdate(USER_ID, 101)).thenReturn(Optional.of(completed));
        UserMissionActionResponse retry = service.complete(USER_KEY, 101);
        assertThat(retry.idempotent()).isTrue();
        verify(repository).markCompleted(eq(101L), any());
    }

    @Test
    void hidesNonOwnedMissionAsNotFoundAndRejectsInvalidIds() {
        when(repository.findOwnedForUpdate(USER_ID, 999)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.select(USER_KEY, 999))
                .isInstanceOf(UserMissionNotFoundException.class);
        assertThatThrownBy(() -> service.select(USER_KEY, 0))
                .isInstanceOf(InvalidMissionRequestException.class);
        assertThatThrownBy(() -> service.replace(
                        USER_KEY, 101, new ReplacementMissionRequest(101)))
                .isInstanceOf(InvalidMissionRequestException.class);
    }

    private UserMissionState state(long id, MissionStatus status, Integer slot) {
        return new UserMissionState(id, id - 100, MissionCategory.MOVEMENT, status, TODAY, slot);
    }

    private UserMissionResponse response(long id, MissionStatus status) {
        return new UserMissionResponse(
                id, id - 100, "미션", "설명", MissionCategory.MOVEMENT,
                1, 5, 1, 1, 2, 2, MissionSourceType.BASE,
                0.8, 0.8, status, OffsetDateTime.parse("2026-08-20T09:00:00+09:00"));
    }

    private MissionTodayResponse today() {
        return new MissionTodayResponse(TODAY, SETTINGS, 0, 2, List.of(), List.of());
    }

    private MissionSummaryResponse summary(int completedCount) {
        return new MissionSummaryResponse(
                completedCount, 0, "QUIET_FOCUSER", List.of());
    }
}
