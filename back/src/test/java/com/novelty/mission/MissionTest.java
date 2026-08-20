package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class MissionTest {

    @Test
    void acceptsCatalogBoundaryValues() {
        new Mission(
                1,
                "미션",
                "설명",
                MissionCategory.CULTURE,
                3,
                180,
                1,
                -1,
                2,
                0,
                true,
                MissionSourceType.BASE);
    }

    @Test
    void rejectsInvalidIdentityTextAndRequiredEnums() {
        assertThatThrownBy(() -> mission(0, "미션", "설명", MissionCategory.CULTURE, MissionSourceType.BASE))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> mission(1, " ", "설명", MissionCategory.CULTURE, MissionSourceType.BASE))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> mission(1, "미션", " ", MissionCategory.CULTURE, MissionSourceType.BASE))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> mission(1, "미션", "설명", null, MissionSourceType.BASE))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> mission(1, "미션", "설명", MissionCategory.CULTURE, null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void rejectsValuesOutsideOracleCatalogRanges() {
        assertThatThrownBy(() -> withValues(0, 5, 0, 0, 1, 1)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> withValues(4, 5, 0, 0, 1, 1)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> withValues(1, 0, 0, 0, 1, 1)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> withValues(1, 181, 0, 0, 1, 1)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> withValues(1, 5, -2, 0, 1, 1)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> withValues(1, 5, 0, 2, 1, 1)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> withValues(1, 5, 0, 0, 3, 1)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> withValues(1, 5, 0, 0, 1, -1)).isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void recommendationRejectsNonFiniteOrOutOfRangeScores() {
        Mission mission = withValues(1, 5, 0, 0, 1, 1);
        assertThatThrownBy(() -> new MissionRecommendation(mission, Double.NaN, 1, 1, 1))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new MissionRecommendation(mission, 0, 1.1, 1, 1))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new MissionRecommendation(null, 0, 1, 1, 1))
                .isInstanceOf(IllegalArgumentException.class);
    }

    private Mission mission(
            long id,
            String title,
            String description,
            MissionCategory category,
            MissionSourceType sourceType) {
        return new Mission(id, title, description, category, 1, 5, 0, 0, 1, 1, true, sourceType);
    }

    private Mission withValues(
            int difficulty,
            int minutes,
            int indoorOutdoor,
            int socialLevel,
            int activityLevel,
            int noveltyLevel) {
        return new Mission(
                1,
                "미션",
                "설명",
                MissionCategory.CULTURE,
                difficulty,
                minutes,
                indoorOutdoor,
                socialLevel,
                activityLevel,
                noveltyLevel,
                true,
                MissionSourceType.BASE);
    }
}
