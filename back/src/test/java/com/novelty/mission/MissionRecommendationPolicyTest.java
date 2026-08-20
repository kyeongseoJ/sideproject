package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class MissionRecommendationPolicyTest {

    private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");
    private static final Instant NOW = Instant.parse("2026-08-20T03:00:00Z");

    private MissionRecommendationPolicy policy;

    @BeforeEach
    void setUp() {
        policy = new MissionRecommendationPolicy(Clock.fixed(NOW, SEOUL));
    }

    @Test
    void calculatesTheDocumentedWeightedScore() {
        UserMissionVector user = new UserMissionVector(-1, -1, 0, 0, 0);
        Mission mission = mission(1, MissionCategory.CREATIVE, 3, 5, 1, 1, 2, 2, true, MissionSourceType.BASE);

        MissionRecommendation result = recommend(
                List.of(mission), user, AvailableTime.QUICK, Map.of(MissionCategory.CREATIVE, 3), List.of())
                .getFirst();

        assertThat(result.personalityDistance()).isEqualTo(1.0);
        assertThat(result.categoryExplorationScore()).isEqualTo(0.25);
        assertThat(result.difficultyFitScore()).isZero();
        assertThat(result.recommendationScore()).isEqualTo(0.75);
    }

    @Test
    void filtersDisabledTooLongAndLlmMissionsForNewUser() {
        UserMissionVector user = vector(0);
        List<Mission> missions = List.of(
                mission(1, MissionCategory.MOVEMENT, 1, 15, true, MissionSourceType.BASE),
                mission(2, MissionCategory.FOOD, 1, 5, false, MissionSourceType.BASE),
                mission(3, MissionCategory.CULTURE, 1, 5, true, MissionSourceType.LLM),
                mission(4, MissionCategory.LEARNING, 1, 5, true, MissionSourceType.BASE));

        assertThat(ids(recommend(missions, user, AvailableTime.QUICK, Map.of(), List.of())))
                .containsExactly(4L);
    }

    @Test
    void includesSharedLlmMissionFromFiveCompletions() {
        List<Mission> missions = List.of(
                mission(1, MissionCategory.MOVEMENT, 1, 5, true, MissionSourceType.BASE),
                mission(2, MissionCategory.CULTURE, 1, 5, true, MissionSourceType.LLM));

        assertThat(ids(recommend(missions, vector(5), AvailableTime.QUICK, Map.of(), List.of())))
                .containsExactlyInAnyOrder(1L, 2L);
    }

    @Test
    void appliesCompletedAndShownCalendarWindowsAndIgnoresFutureEvents() {
        List<Mission> missions = List.of(
                mission(1, MissionCategory.MOVEMENT),
                mission(2, MissionCategory.FOOD),
                mission(3, MissionCategory.CULTURE),
                mission(4, MissionCategory.LEARNING),
                mission(5, MissionCategory.SOCIAL));
        List<MissionStatusEvent> history = List.of(
                event(1, MissionCategory.MOVEMENT, MissionStatus.COMPLETED, "2026-08-18T10:00:00+09:00"),
                event(2, MissionCategory.FOOD, MissionStatus.COMPLETED, "2026-08-17T23:59:00+09:00"),
                event(3, MissionCategory.CULTURE, MissionStatus.SHOWN, "2026-08-19T09:00:00+09:00"),
                event(4, MissionCategory.LEARNING, MissionStatus.SHOWN, "2026-08-18T23:59:00+09:00"),
                event(5, MissionCategory.SOCIAL, MissionStatus.SHOWN, "2026-08-21T09:00:00+09:00"));

        assertThat(ids(recommend(missions, vector(0), AvailableTime.SHORT, Map.of(), history)))
                .containsExactlyInAnyOrder(2L, 4L, 5L);
    }

    @Test
    void usesAsiaSeoulDateAtUtcBoundary() {
        Mission mission = mission(1, MissionCategory.MOVEMENT);
        MissionStatusEvent shown = new MissionStatusEvent(
                1,
                MissionCategory.MOVEMENT.name(),
                MissionStatus.SHOWN,
                OffsetDateTime.parse("2026-08-18T15:30:00Z"));

        assertThat(recommend(
                        List.of(mission), vector(0), AvailableTime.SHORT, Map.of(), List.of(shown)))
                .isEmpty();
    }

    @Test
    void returnsAtMostFiveCandidatesWithDistinctCategoriesFirst() {
        List<Mission> missions = List.of(
                mission(1, MissionCategory.MOVEMENT),
                mission(2, MissionCategory.CREATIVE),
                mission(3, MissionCategory.FOOD),
                mission(4, MissionCategory.LEARNING),
                mission(5, MissionCategory.SOCIAL),
                mission(6, MissionCategory.OUTDOOR),
                mission(7, MissionCategory.ORGANIZING),
                mission(8, MissionCategory.CULTURE),
                mission(9, MissionCategory.MOVEMENT));

        List<MissionRecommendation> results = recommend(
                missions, vector(0), AvailableTime.SHORT, Map.of(), List.of());

        assertThat(results).hasSize(5);
        assertThat(results.stream().map(result -> result.mission().category()).distinct())
                .hasSize(5);
    }

    @Test
    void defersMostRecentSelectedOrCompletedCategoryWithoutRemovingIt() {
        List<Mission> missions = List.of(
                mission(1, MissionCategory.MOVEMENT),
                mission(2, MissionCategory.FOOD));
        List<MissionStatusEvent> history = List.of(
                event(90, MissionCategory.MOVEMENT, MissionStatus.SELECTED, "2026-08-20T09:00:00+09:00"));

        List<MissionRecommendation> results = recommend(
                missions, vector(0), AvailableTime.SHORT, Map.of(), history);

        assertThat(ids(results)).containsExactly(2L, 1L);
    }

    @Test
    void ignoresFuturePerformedCategoryWhenApplyingCategoryDiversity() {
        List<Mission> missions = List.of(
                mission(1, MissionCategory.MOVEMENT),
                mission(2, MissionCategory.FOOD));
        List<MissionStatusEvent> history = List.of(
                event(90, MissionCategory.MOVEMENT, MissionStatus.SELECTED, "2026-08-21T09:00:00+09:00"));

        List<MissionRecommendation> results = policy.recommend(
                missions,
                vector(0),
                AvailableTime.SHORT,
                Map.of(),
                history,
                new ZeroRandom());

        assertThat(ids(results)).containsExactly(1L, 2L);
    }

    @Test
    void allowsRepeatedCategoryOnlyWhenDistinctCategoriesAreExhausted() {
        List<Mission> missions = List.of(
                mission(1, MissionCategory.MOVEMENT),
                mission(2, MissionCategory.MOVEMENT),
                mission(3, MissionCategory.FOOD),
                mission(4, MissionCategory.FOOD));

        List<MissionRecommendation> results = recommend(
                missions, vector(0), AvailableTime.SHORT, Map.of(), List.of());

        assertThat(results).hasSize(4);
        assertThat(results.get(0).mission().category())
                .isNotEqualTo(results.get(1).mission().category());
    }

    @Test
    void limitsWeightedRandomSelectionToTopTenRankedMissions() {
        List<Mission> missions = new ArrayList<>();
        for (long id = 1; id <= 10; id++) {
            missions.add(mission(
                    id, MissionCategory.MOVEMENT, 1, 5, 1, 1, 2, 2, true, MissionSourceType.BASE));
        }
        missions.add(mission(
                11, MissionCategory.MOVEMENT, 3, 5, -1, -1, 0, 0, true, MissionSourceType.BASE));

        assertThat(ids(recommend(
                        missions,
                        new UserMissionVector(-1, -1, 0, 0, 0),
                        AvailableTime.QUICK,
                        Map.of(MissionCategory.MOVEMENT, 100),
                        List.of())))
                .doesNotContain(11L);
    }

    @Test
    void producesReproducibleWeightedSelectionWithFixedRandomSeed() {
        List<Mission> missions = List.of(
                mission(1, MissionCategory.MOVEMENT),
                mission(2, MissionCategory.CREATIVE),
                mission(3, MissionCategory.FOOD),
                mission(4, MissionCategory.LEARNING),
                mission(5, MissionCategory.SOCIAL),
                mission(6, MissionCategory.OUTDOOR));

        List<Long> first = ids(policy.recommend(
                missions, vector(0), AvailableTime.SHORT, Map.of(), List.of(), new Random(9876)));
        List<Long> second = ids(policy.recommend(
                missions, vector(0), AvailableTime.SHORT, Map.of(), List.of(), new Random(9876)));

        assertThat(first).isEqualTo(second).doesNotHaveDuplicates();
    }

    @Test
    void returnsAllEligibleMissionsWhenThereAreFewerThanFive() {
        List<Mission> missions = List.of(
                mission(1, MissionCategory.MOVEMENT),
                mission(2, MissionCategory.FOOD));

        assertThat(ids(recommend(missions, vector(0), AvailableTime.SHORT, Map.of(), List.of())))
                .containsExactlyInAnyOrder(1L, 2L);
    }

    @Test
    void returnsEmptyWhenEveryMissionIsIneligible() {
        List<Mission> missions = List.of(
                mission(1, MissionCategory.MOVEMENT, 1, 60, true, MissionSourceType.BASE),
                mission(2, MissionCategory.FOOD, 1, 5, false, MissionSourceType.BASE));

        assertThat(recommend(missions, vector(0), AvailableTime.QUICK, Map.of(), List.of()))
                .isEmpty();
    }

    @Test
    void rejectsDuplicateMissionIdsAndInvalidCategoryCounts() {
        Mission mission = mission(1, MissionCategory.MOVEMENT);
        assertThatThrownBy(() -> recommend(
                        List.of(mission, mission), vector(0), AvailableTime.SHORT, Map.of(), List.of()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("duplicate mission id");

        Map<MissionCategory, Integer> negative = new HashMap<>();
        negative.put(MissionCategory.MOVEMENT, -1);
        assertThatThrownBy(() -> recommend(
                        List.of(mission), vector(0), AvailableTime.SHORT, negative, List.of()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("non-negative");
    }

    @Test
    void rejectsNullAndInvalidHistoryEntries() {
        Mission mission = mission(1, MissionCategory.MOVEMENT);
        assertThatThrownBy(() -> policy.recommend(
                        null, vector(0), AvailableTime.SHORT, Map.of(), List.of(), new Random(1)))
                .isInstanceOf(NullPointerException.class);
        assertThatThrownBy(() -> recommend(
                        List.of(mission),
                        vector(0),
                        AvailableTime.SHORT,
                        Map.of(),
                        Collections.singletonList(null)))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("history");
        MissionStatusEvent invalidCategory = new MissionStatusEvent(
                1, "UNKNOWN", MissionStatus.SHOWN, OffsetDateTime.parse("2026-08-20T10:00:00+09:00"));
        assertThatThrownBy(() -> recommend(
                        List.of(mission), vector(0), AvailableTime.SHORT, Map.of(), List.of(invalidCategory)))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("category");
        MissionStatusEvent invalidMissionId = new MissionStatusEvent(
                0, MissionCategory.MOVEMENT.name(), MissionStatus.SHOWN,
                OffsetDateTime.parse("2026-08-20T10:00:00+09:00"));
        assertThatThrownBy(() -> recommend(
                        List.of(mission), vector(0), AvailableTime.SHORT, Map.of(), List.of(invalidMissionId)))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("history");
    }

    private List<MissionRecommendation> recommend(
            List<Mission> missions,
            UserMissionVector vector,
            AvailableTime availableTime,
            Map<MissionCategory, Integer> categoryCounts,
            List<MissionStatusEvent> history) {
        return policy.recommend(
                missions,
                vector,
                availableTime,
                categoryCounts,
                history,
                new Random(1234));
    }

    private UserMissionVector vector(int completedCount) {
        return new UserMissionVector(-1, -1, 0, 0, completedCount);
    }

    private Mission mission(long id, MissionCategory category) {
        return mission(id, category, 1, 5, 1, 1, 2, 2, true, MissionSourceType.BASE);
    }

    private Mission mission(
            long id,
            MissionCategory category,
            int difficulty,
            int estimatedMinutes,
            boolean enabled,
            MissionSourceType sourceType) {
        return mission(id, category, difficulty, estimatedMinutes, 1, 1, 2, 2, enabled, sourceType);
    }

    private Mission mission(
            long id,
            MissionCategory category,
            int difficulty,
            int estimatedMinutes,
            int indoorOutdoor,
            int socialLevel,
            int activityLevel,
            int noveltyLevel,
            boolean enabled,
            MissionSourceType sourceType) {
        return new Mission(
                id,
                "미션 " + id,
                "설명 " + id,
                category,
                difficulty,
                estimatedMinutes,
                indoorOutdoor,
                socialLevel,
                activityLevel,
                noveltyLevel,
                enabled,
                sourceType);
    }

    private MissionStatusEvent event(
            long missionId,
            MissionCategory category,
            MissionStatus status,
            String occurredAt) {
        return new MissionStatusEvent(
                missionId,
                category.name(),
                status,
                OffsetDateTime.parse(occurredAt));
    }

    private List<Long> ids(List<MissionRecommendation> recommendations) {
        return recommendations.stream().map(result -> result.mission().id()).toList();
    }

    private static final class ZeroRandom extends Random {

        @Override
        public double nextDouble(double bound) {
            return 0.0;
        }
    }
}
