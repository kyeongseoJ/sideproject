package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Arrays;

import org.junit.jupiter.api.Test;

class MissionCategoryContractTest {

    @Test
    void usesCanonicalCategoryCodesForApiAndDatabaseValues() {
        assertThat(Arrays.stream(MissionCategory.values()).map(Enum::name))
                .containsExactly(
                        "MOVEMENT",
                        "CREATIVE",
                        "FOOD",
                        "LEARNING",
                        "SOCIAL",
                        "OUTDOOR",
                        "ORGANIZING",
                        "CULTURE");
    }
}
