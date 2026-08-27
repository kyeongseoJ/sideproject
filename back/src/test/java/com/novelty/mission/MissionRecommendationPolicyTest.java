package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Clock;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.random.RandomGenerator;
import java.util.OptionalDouble;

import org.junit.jupiter.api.Test;

import com.novelty.personality.ExecutionStyle;

class MissionRecommendationPolicyTest {

    private final MissionRecommendationPolicy policy = new MissionRecommendationPolicy(
            Clock.systemUTC(), (left, right) -> OptionalDouble.empty());

    @Test
    void executionStyleChangesRecommendationFit() {
        UserMissionVector vector = new UserMissionVector(0, 0, 1, 1, 0);

        MissionRecommendation planned = recommend(
                mission(1L, MissionCategory.ORGANIZING), vector, ExecutionStyle.PLANNED);
        MissionRecommendation spontaneous = recommend(
                mission(2L, MissionCategory.OUTDOOR), vector, ExecutionStyle.PLANNED);

        assertThat(planned.contextFitScore()).isGreaterThan(spontaneous.contextFitScore());
        assertThat(planned.recommendationScore()).isGreaterThan(spontaneous.recommendationScore());
    }

    private MissionRecommendation recommend(
            Mission mission,
            UserMissionVector vector,
            ExecutionStyle executionStyle) {
        return policy.recommend(
                List.of(mission),
                vector,
                Set.of(),
                executionStyle,
                Map.of(),
                List.of(),
                RandomGenerator.getDefault())
                .getFirst();
    }

    private Mission mission(long id, MissionCategory category) {
        return new Mission(id, "미션 " + id, "설명 " + id, category,
                1, 30, 0, 0, 1, 1, true, MissionSourceType.BASE);
    }
}
