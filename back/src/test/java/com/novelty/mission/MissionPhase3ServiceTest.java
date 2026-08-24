package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
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
import java.util.Map;
import java.util.Optional;
import java.util.Random;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.TransactionStatus;
import org.springframework.transaction.support.TransactionCallback;
import org.springframework.transaction.support.TransactionTemplate;

import com.novelty.user.UserService;

class MissionPhase3ServiceTest {

    private static final String USER_KEY = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    private static final long USER_ID = 7L;
    private static final LocalDate SERVICE_DATE = LocalDate.of(2026, 8, 20);

    private UserService userService;
    private MissionRepository missionRepository;
    private MissionStatusLogRepository statusLogRepository;
    private UserMissionRepository userMissionRepository;
    private MissionRecommendationPolicy recommendationPolicy;
    private TransactionTemplate transactionTemplate;
    private MissionService service;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        userService = mock(UserService.class);
        missionRepository = mock(MissionRepository.class);
        statusLogRepository = mock(MissionStatusLogRepository.class);
        userMissionRepository = mock(UserMissionRepository.class);
        recommendationPolicy = mock(MissionRecommendationPolicy.class);
        transactionTemplate = mock(TransactionTemplate.class);
        when(userService.requireUserId(USER_KEY)).thenReturn(USER_ID);
        when(transactionTemplate.execute(any())).thenAnswer(invocation -> {
            TransactionCallback<?> callback = invocation.getArgument(0);
            return callback.doInTransaction(mock(TransactionStatus.class));
        });
        service = new MissionService(
                userService,
                missionRepository,
                statusLogRepository,
                userMissionRepository,
                recommendationPolicy,
                transactionTemplate,
                Clock.fixed(Instant.parse("2026-08-20T00:00:00Z"), ZoneId.of("Asia/Seoul")),
                new Random(1234));
    }

    @Test
    void savesAndReadsValidatedSettings() {
        MissionSettingsResponse expected = new MissionSettingsResponse(AvailableTime.SHORT, 2);
        when(userMissionRepository.saveSettings(USER_ID, expected)).thenReturn(expected);
        when(userMissionRepository.findSettings(USER_ID)).thenReturn(Optional.of(expected));

        assertThat(service.saveSettings(
                        USER_KEY, new MissionSettingsRequest(AvailableTime.SHORT, 2)))
                .isEqualTo(expected);
        assertThat(service.getSettings(USER_KEY)).isEqualTo(expected);
    }

    @Test
    void rejectsInvalidOrMissingSettings() {
        assertThatThrownBy(() -> service.saveSettings(
                        USER_KEY, new MissionSettingsRequest(null, 1)))
                .isInstanceOf(InvalidMissionRequestException.class);
        assertThatThrownBy(() -> service.saveSettings(
                        USER_KEY, new MissionSettingsRequest(AvailableTime.SHORT, 4)))
                .isInstanceOf(InvalidMissionRequestException.class);
        when(userMissionRepository.findSettings(USER_ID)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.getSettings(USER_KEY))
                .isInstanceOf(MissionSettingsRequiredException.class);
    }

    @Test
    void createsAndPersistsDailyRecommendationsOnce() {
        MissionSettingsResponse settings = new MissionSettingsResponse(AvailableTime.SHORT, 1);
        UserMissionVector vector = new UserMissionVector(-1, -1, 0, 0, 0);
        Mission first = mission(1, MissionCategory.MOVEMENT);
        Mission second = mission(2, MissionCategory.CULTURE);
        List<MissionRecommendation> recommendations = List.of(
                recommendation(first, 0.9), recommendation(second, 0.8));
        List<UserMissionResponse> stored = List.of(
                userMission(101, first, 0.9), userMission(102, second, 0.8));

        when(userMissionRepository.findSettings(USER_ID)).thenReturn(Optional.of(settings));
        when(userMissionRepository.findToday(USER_ID, SERVICE_DATE))
                .thenReturn(List.of(), stored);
        when(missionRepository.findUserVector(USER_ID)).thenReturn(Optional.of(vector));
        when(missionRepository.findCandidates(15, false)).thenReturn(List.of(first, second));
        when(userMissionRepository.findCategoryCompletionCounts(USER_ID)).thenReturn(Map.of());
        when(statusLogRepository.findAll(USER_ID)).thenReturn(List.of());
        when(recommendationPolicy.recommend(
                any(), eq(vector), eq(AvailableTime.SHORT), any(), any(), any()))
                .thenReturn(recommendations);
        when(userMissionRepository.insertRecommendation(
                eq(USER_ID), eq(SERVICE_DATE), eq(AvailableTime.SHORT),
                any(), eq(recommendations.get(0)), any()))
                .thenReturn(101L);
        when(userMissionRepository.insertRecommendation(
                eq(USER_ID), eq(SERVICE_DATE), eq(AvailableTime.SHORT),
                any(), eq(recommendations.get(1)), any()))
                .thenReturn(102L);

        MissionRecommendationBatchResult result = service.recommendToday(USER_KEY);

        assertThat(result.created()).isTrue();
        assertThat(result.response().candidates()).hasSize(2);
        verify(userMissionRepository).lockUser(USER_ID);
        verify(userMissionRepository).insertRecommendation(
                eq(USER_ID), eq(SERVICE_DATE), eq(AvailableTime.SHORT),
                any(), eq(recommendations.get(0)), any());
        verify(statusLogRepository).append(
                eq(USER_ID), eq(1L), eq(101L), eq("MOVEMENT"),
                eq(null), eq(MissionStatus.GENERATED), eq("DAILY_RECOMMENDATION"), any());
    }

    @Test
    void reusesExistingDailyRecommendationsWithoutGeneratingAgain() {
        MissionSettingsResponse settings = new MissionSettingsResponse(AvailableTime.QUICK, 1);
        Mission mission = mission(1, MissionCategory.FOOD);
        when(userMissionRepository.findSettings(USER_ID)).thenReturn(Optional.of(settings));
        when(userMissionRepository.findToday(USER_ID, SERVICE_DATE))
                .thenReturn(List.of(userMission(101, mission, 0.7)));

        MissionRecommendationBatchResult result = service.recommendToday(USER_KEY);

        assertThat(result.created()).isFalse();
        assertThat(result.response().candidates()).hasSize(1);
        verify(recommendationPolicy, never()).recommend(any(), any(), any(), any(), any(), any());
        verify(userMissionRepository, never()).insertRecommendation(
                anyLong(), any(), any(), any(), any(), any());
    }

    @Test
    void rejectsRecommendationWhenSettingsPersonalityOrCandidatesAreMissing() {
        when(userMissionRepository.findSettings(USER_ID)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.recommendToday(USER_KEY))
                .isInstanceOf(MissionSettingsRequiredException.class);

        MissionSettingsResponse settings = new MissionSettingsResponse(AvailableTime.SHORT, 1);
        when(userMissionRepository.findSettings(USER_ID)).thenReturn(Optional.of(settings));
        when(userMissionRepository.findToday(USER_ID, SERVICE_DATE)).thenReturn(List.of());
        when(missionRepository.findUserVector(USER_ID)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.recommendToday(USER_KEY))
                .isInstanceOf(PersonalityRequiredException.class);

        UserMissionVector vector = new UserMissionVector(0, 0, 1, 1, 0);
        when(missionRepository.findUserVector(USER_ID)).thenReturn(Optional.of(vector));
        when(missionRepository.findCandidates(15, false)).thenReturn(List.of());
        when(userMissionRepository.findCategoryCompletionCounts(USER_ID)).thenReturn(Map.of());
        when(statusLogRepository.findAll(USER_ID)).thenReturn(List.of());
        when(recommendationPolicy.recommend(any(), any(), any(), any(), any(), any()))
                .thenReturn(List.of());
        assertThatThrownBy(() -> service.recommendToday(USER_KEY))
                .isInstanceOf(NoMissionAvailableException.class);
    }

    private Mission mission(long id, MissionCategory category) {
        return new Mission(
                id, "미션 " + id, "설명 " + id, category,
                1, 5, 1, 1, 2, 2, true, MissionSourceType.BASE);
    }

    private MissionRecommendation recommendation(Mission mission, double score) {
        return new MissionRecommendation(mission, score, 1.0, 1.0, score);
    }

    private UserMissionResponse userMission(long userMissionId, Mission mission, double score) {
        return new UserMissionResponse(
                userMissionId,
                mission.id(),
                mission.title(),
                mission.description(),
                mission.category(),
                mission.difficulty(),
                mission.estimatedMinutes(),
                mission.indoorOutdoor(),
                mission.socialLevel(),
                mission.activityLevel(),
                mission.noveltyLevel(),
                mission.sourceType(),
                score,
                score,
                MissionStatus.SHOWN,
                OffsetDateTime.parse("2026-08-20T09:00:00+09:00"));
    }
}
