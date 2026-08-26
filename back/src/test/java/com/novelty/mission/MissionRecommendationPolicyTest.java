package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.within;

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
import java.util.OptionalDouble;
import java.util.Set;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class MissionRecommendationPolicyTest {

    private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");
    private static final Instant NOW = Instant.parse("2026-08-20T03:00:00Z");

    private MissionRecommendationPolicy policy;

    @BeforeEach
    void setUp() {
        policy = new MissionRecommendationPolicy(
                Clock.fixed(NOW, SEOUL), (left, right) -> OptionalDouble.empty());
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
        assertThat(result.noveltyScore()).isEqualTo(1.0);
        assertThat(result.recentDiversityScore()).isEqualTo(1.0);
        assertThat(result.explorationBonus()).isEqualTo(1.0);
        assertThat(result.recommendationScore()).isCloseTo(0.8625, within(0.0001));
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
                .containsExactly(5L);
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
    void returnsAtMostFiveMutuallyDiverseCandidates() {
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

        assertThat(scoreOf(results, 2L)).isGreaterThan(scoreOf(results, 1L));
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

        assertThat(scoreOf(results, 1L)).isEqualTo(scoreOf(results, 2L));
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
    void limitsWeightedRandomSelectionToTopTwentyRankedMissions() {
        List<Mission> missions = new ArrayList<>();
        for (long id = 1; id <= 20; id++) {
            missions.add(mission(
                    id, MissionCategory.MOVEMENT, 1, 5, 1, 1, 2, 2, true, MissionSourceType.BASE));
        }
        missions.add(mission(
                21, MissionCategory.MOVEMENT, 3, 5, -1, -1, 0, 0, true, MissionSourceType.BASE));

        assertThat(ids(recommend(
                        missions,
                        new UserMissionVector(-1, -1, 0, 0, 0),
                        AvailableTime.QUICK,
                        Map.of(MissionCategory.MOVEMENT, 100),
                        List.of())))
                .doesNotContain(21L);
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
    void returnsAllEligibleMissionsWhenThereAreFewerThanThree() {
        List<Mission> missions = List.of(
                mission(1, MissionCategory.MOVEMENT),
                mission(2, MissionCategory.FOOD));

        assertThat(ids(recommend(missions, vector(0), AvailableTime.SHORT, Map.of(), List.of())))
                .containsExactlyInAnyOrder(1L, 2L);
    }

    @Test
    void blocksPhraseVariantThatRepresentsTheSameRecentExperience() {
        Mission completed = detailedMission(
                90, "새로운 동네 카페를 찾아가 보기", "평소와 다른 카페에서 음료를 마셔 보세요.",
                MissionCategory.OUTDOOR, MissionActionType.EXPLORE, 1, -1, 1, 0, 2, 2, 1,
                Set.of("CAFE", "VISIT", "NEW_PLACE"));
        Mission phraseVariant = detailedMission(
                1, "처음 보는 카페 방문하기", "익숙하지 않은 카페 한 곳을 골라 음료를 주문하세요.",
                MissionCategory.OUTDOOR, MissionActionType.EXPLORE, 1, -1, 1, 0, 2, 2, 1,
                Set.of("CAFE", "VISIT", "NEW_PLACE"));
        Mission different = detailedMission(
                2, "오래 연락하지 않은 사람에게 안부 묻기", "짧은 메시지로 안부를 물어보세요.",
                MissionCategory.SOCIAL, MissionActionType.CONNECT, 0, 1, 0, 0, 1, 1, 0,
                Set.of("MESSAGE", "CONTACT"));

        List<MissionRecommendation> results = recommend(
                List.of(phraseVariant, different), vector(5), AvailableTime.SHORT, Map.of(),
                List.of(completedEvent(900, completed, "2026-08-19T10:00:00+09:00")));

        assertThat(ids(results)).containsExactly(2L);
    }

    @Test
    void lowersScoreForRecentlyRepeatedCategoryAndPattern() {
        Mission completed = detailedMission(
                90, "계단 오르기", "가까운 계단을 천천히 올라 보세요.",
                MissionCategory.MOVEMENT, MissionActionType.EXERCISE, 0, -1, 2, 0, 0, 1, 0,
                Set.of("STAIRS", "EXERCISE"));
        Mission repeated = detailedMission(
                1, "새 동작 스트레칭", "처음 해보는 동작으로 몸을 풀어 보세요.",
                MissionCategory.MOVEMENT, MissionActionType.PRACTICE, -1, -1, 1, 0, 1, 1, 0,
                Set.of("STRETCH", "BODY"));
        Mission unexplored = detailedMission(
                2, "한 줄 그림 그리기", "펜을 떼지 않고 작은 그림을 그려 보세요.",
                MissionCategory.CREATIVE, MissionActionType.CREATE, -1, -1, 0, 2, 1, 1, 0,
                Set.of("DRAW", "ART"));
        List<MissionRecommendation> results = recommend(
                List.of(repeated, unexplored), vector(5), AvailableTime.SHORT, Map.of(),
                List.of(completedEvent(900, completed, "2026-08-19T10:00:00+09:00")));

        assertThat(scoreOf(results, 2L)).isGreaterThan(scoreOf(results, 1L));
        assertThat(recommendationOf(results, 1L).repetitionPenalty()).isPositive();
    }

    @Test
    void givesExplorationAdvantageToAnUnseenCategory() {
        Mission movement = mission(1, MissionCategory.MOVEMENT);
        Mission culture = mission(2, MissionCategory.CULTURE);

        List<MissionRecommendation> results = recommend(
                List.of(movement, culture), vector(5), AvailableTime.SHORT,
                Map.of(MissionCategory.MOVEMENT, 8), List.of());

        assertThat(scoreOf(results, 2L)).isGreaterThan(scoreOf(results, 1L));
    }

    @Test
    void finalThreeAvoidOverlappingExperiencePatterns() {
        Mission cafe = detailedMission(
                1, "새 카페 방문", "가보지 않은 카페에 가세요.", MissionCategory.OUTDOOR,
                MissionActionType.EXPLORE, 1, -1, 1, 0, 2, 2, 1, Set.of("CAFE", "VISIT"));
        Mission restaurant = detailedMission(
                2, "새 식당 방문", "가보지 않은 식당에 가세요.", MissionCategory.OUTDOOR,
                MissionActionType.EXPLORE, 1, -1, 1, 0, 2, 2, 1, Set.of("RESTAURANT", "VISIT"));
        Mission place = detailedMission(
                3, "새 장소 방문", "익숙하지 않은 장소에 가세요.", MissionCategory.OUTDOOR,
                MissionActionType.EXPLORE, 1, -1, 1, 0, 2, 2, 1, Set.of("PLACE", "VISIT"));
        Mission contact = detailedMission(
                4, "안부 연락", "오래 연락하지 않은 사람에게 안부를 물으세요.", MissionCategory.SOCIAL,
                MissionActionType.CONNECT, 0, 1, 0, 0, 1, 1, 0, Set.of("MESSAGE", "CONTACT"));
        Mission create = detailedMission(
                5, "종이로 작은 모형 만들기", "종이를 접어 작은 모형을 만드세요.", MissionCategory.CREATIVE,
                MissionActionType.CREATE, -1, -1, 0, 2, 1, 1, 0, Set.of("PAPER", "CRAFT"));

        List<MissionRecommendation> results = policy.recommend(
                List.of(cafe, restaurant, place, contact, create), vector(5), AvailableTime.SHORT,
                Map.of(), List.of(), new ZeroRandom());

        assertThat(results).hasSize(5);
        assertThat(results.stream().map(result -> result.mission().category()).distinct()).hasSize(3);
        assertThat(results.stream().map(result -> result.mission().actionType()).distinct()).hasSize(3);
    }

    @Test
    void preservesPersonalityDistanceAsARecommendationSignal() {
        UserMissionVector user = new UserMissionVector(-1, -1, 0, 0, 5);
        Mission far = mission(1, MissionCategory.CREATIVE, 1, 5, 1, 1, 2, 2, true, MissionSourceType.BASE);
        Mission near = mission(2, MissionCategory.MOVEMENT, 1, 5, -1, -1, 0, 0, true, MissionSourceType.BASE);

        List<MissionRecommendation> results = recommend(
                List.of(far, near), user, AvailableTime.QUICK, Map.of(), List.of());

        assertThat(recommendationOf(results, 1L).personalityDistance())
                .isGreaterThan(recommendationOf(results, 2L).personalityDistance());
        assertThat(scoreOf(results, 1L)).isGreaterThan(scoreOf(results, 2L));
    }

    @Test
    void appliesMoreSimilarityPenaltyToMoreRecentExperience() {
        Mission completed = detailedMission(
                90, "공원 식물 관찰", "공원에서 식물을 관찰하세요.", MissionCategory.OUTDOOR,
                MissionActionType.OBSERVE, 1, -1, 1, 1, 1, 1, 0, Set.of("NATURE", "OBSERVE"));
        Mission candidate = detailedMission(
                1, "거리 간판 관찰", "거리에서 낯선 간판을 관찰하세요.", MissionCategory.OUTDOOR,
                MissionActionType.OBSERVE, 1, -1, 0, 0, 2, 2, 0, Set.of("SIGN", "STREET"));

        MissionRecommendation recent = recommendationOf(recommend(
                List.of(candidate), vector(5), AvailableTime.SHORT, Map.of(),
                List.of(completedEvent(900, completed, "2026-08-20T09:00:00+09:00"))), 1L);
        MissionRecommendation older = recommendationOf(recommend(
                List.of(candidate), vector(5), AvailableTime.SHORT, Map.of(),
                List.of(completedEvent(901, completed, "2026-08-14T09:00:00+09:00"))), 1L);

        assertThat(recent.similarityPenalty()).isGreaterThan(older.similarityPenalty());
        assertThat(recent.recommendationScore()).isLessThan(older.recommendationScore());
    }

    @Test
    void appliesDedicatedLongTermPenaltyAfterTheIdentityHardBlock() {
        Mission candidate = mission(1, MissionCategory.MOVEMENT);

        assertThat(recommend(
                List.of(candidate), vector(5), AvailableTime.SHORT, Map.of(),
                List.of(completedEvent(900, candidate, "2026-08-17T09:00:00+09:00"))))
                .isEmpty();

        MissionRecommendation veryHigh = recommendationOf(recommend(
                List.of(candidate), vector(5), AvailableTime.SHORT, Map.of(),
                List.of(completedEvent(901, candidate, "2026-08-16T09:00:00+09:00"))), 1L);
        MissionRecommendation high = recommendationOf(recommend(
                List.of(candidate), vector(5), AvailableTime.SHORT, Map.of(),
                List.of(completedEvent(902, candidate, "2026-08-12T09:00:00+09:00"))), 1L);
        MissionRecommendation low = recommendationOf(recommend(
                List.of(candidate), vector(5), AvailableTime.SHORT, Map.of(),
                List.of(completedEvent(903, candidate, "2026-07-21T09:00:00+09:00"))), 1L);
        MissionRecommendation expired = recommendationOf(recommend(
                List.of(candidate), vector(5), AvailableTime.SHORT, Map.of(),
                List.of(completedEvent(904, candidate, "2026-07-20T09:00:00+09:00"))), 1L);

        assertThat(veryHigh.longTermRepeatPenalty()).isEqualTo(0.35);
        assertThat(high.longTermRepeatPenalty()).isEqualTo(0.20);
        assertThat(low.longTermRepeatPenalty()).isEqualTo(0.08);
        assertThat(expired.longTermRepeatPenalty()).isZero();
        assertThat(veryHigh.similarityPenalty()).isZero();
        assertThat(veryHigh.repetitionPenalty()).isPositive();
        assertThat(veryHigh.recommendationScore()).isLessThan(high.recommendationScore());
        assertThat(high.recommendationScore()).isLessThan(low.recommendationScore());
        assertThat(low.recommendationScore()).isLessThan(expired.recommendationScore());
    }

    @Test
    void repeatedSkippedPatternsLowerFrequencyWithoutHardRemoval() {
        Mission skipped = detailedMission(
                90, "직원에게 추천 묻기", "직원에게 추천을 물으세요.", MissionCategory.SOCIAL,
                MissionActionType.ASK, 1, 1, 0, 0, 2, 2, 1, Set.of("ASK", "SHOP"));
        Mission candidate = detailedMission(
                1, "낯선 사람에게 길 묻기", "안전한 장소에서 길을 물으세요.", MissionCategory.SOCIAL,
                MissionActionType.ASK, 1, 1, 0, 0, 2, 2, 1, Set.of("ASK", "DIRECTION"));
        List<MissionStatusEvent> history = List.of(
                shownEvent(900, skipped, "2026-08-19T09:00:00+09:00"),
                shownEvent(901, skipped, "2026-08-18T09:00:00+09:00"));

        MissionRecommendation result = recommendationOf(recommend(
                List.of(candidate), vector(5), AvailableTime.SHORT, Map.of(), history), 1L);

        assertThat(result.rejectionPenalty()).isPositive();
        assertThat(result.recommendationScore()).isPositive();
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

    private Mission detailedMission(
            long id,
            String title,
            String description,
            MissionCategory category,
            MissionActionType actionType,
            int indoorOutdoor,
            int socialLevel,
            int activityLevel,
            int creativityLevel,
            int unpredictabilityLevel,
            int comfortZoneDistance,
            int costLevel,
            Set<String> tags) {
        return new Mission(
                id, title, description, category, 1, 10,
                indoorOutdoor, socialLevel, activityLevel, 2,
                actionType, creativityLevel, unpredictabilityLevel,
                comfortZoneDistance, costLevel, tags, true, MissionSourceType.BASE);
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

    private MissionStatusEvent completedEvent(
            long userMissionId,
            Mission mission,
            String occurredAt) {
        return new MissionStatusEvent(
                mission.id(), mission.category().name(), mission, userMissionId,
                MissionStatus.COMPLETED, OffsetDateTime.parse(occurredAt));
    }

    private MissionStatusEvent shownEvent(
            long userMissionId,
            Mission mission,
            String occurredAt) {
        return new MissionStatusEvent(
                mission.id(), mission.category().name(), mission, userMissionId,
                MissionStatus.SHOWN, OffsetDateTime.parse(occurredAt));
    }

    private MissionRecommendation recommendationOf(
            List<MissionRecommendation> recommendations,
            long missionId) {
        return recommendations.stream()
                .filter(result -> result.mission().id() == missionId)
                .findFirst()
                .orElseThrow();
    }

    private double scoreOf(List<MissionRecommendation> recommendations, long missionId) {
        return recommendationOf(recommendations, missionId).recommendationScore();
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
