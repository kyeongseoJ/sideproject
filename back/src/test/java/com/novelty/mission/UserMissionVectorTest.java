package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class UserMissionVectorTest {

    @Test
    void distanceIsZeroForSameVectorAndOneForExactOpposite() {
        UserMissionVector user = new UserMissionVector(-1, -1, 0, 0, 0);

        assertThat(user.distanceFrom(mission(-1, -1, 0, 0))).isZero();
        assertThat(user.distanceFrom(mission(1, 1, 2, 2))).isEqualTo(1.0);
    }

    @Test
    void fartherMissionGetsHigherDistance() {
        UserMissionVector user = new UserMissionVector(-1, 0, 0, 1, 0);

        assertThat(user.distanceFrom(mission(1, 1, 2, 2)))
                .isGreaterThan(user.distanceFrom(mission(0, 0, 1, 1)));
    }

    private Mission mission(int indoorOutdoor, int social, int activity, int novelty) {
        return new Mission(
                1L,
                "미션",
                "설명",
                MissionCategory.CREATIVE,
                1,
                10,
                indoorOutdoor,
                social,
                activity,
                novelty,
                true,
                MissionSourceType.BASE);
    }
}
