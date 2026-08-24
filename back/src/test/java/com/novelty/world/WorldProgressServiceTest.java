package com.novelty.world;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.novelty.mission.MissionCategory;
import com.novelty.user.UserService;
import com.novelty.world.WorldRepository.UserWorldProgress;
import com.novelty.world.WorldRepository.WorldObjectDefinition;

class WorldProgressServiceTest {

    private WorldRepository repository;
    private WorldProgressService service;

    @BeforeEach
    void setUp() {
        repository = mock(WorldRepository.class);
        service = new WorldProgressService(mock(UserService.class), repository);
        when(repository.findDefinition(MissionCategory.LEARNING))
                .thenReturn(Optional.of(new WorldObjectDefinition(
                        4L, "BOOKSHELF", MissionCategory.LEARNING, 5)));
    }

    @Test
    void mapsDifficultyToRewardExp() {
        assertThat(WorldProgressService.rewardExp(1)).isEqualTo(10);
        assertThat(WorldProgressService.rewardExp(2)).isEqualTo(20);
        assertThat(WorldProgressService.rewardExp(3)).isEqualTo(30);
    }

    @Test
    void rejectsUnsupportedDifficulty() {
        assertThatThrownBy(() -> WorldProgressService.rewardExp(0))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> WorldProgressService.rewardExp(4))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void appliesExpAndReturnsLevelUpResult() {
        when(repository.findProgressForUpdate(9L, 4L))
                .thenReturn(Optional.of(new UserWorldProgress(40, 1)));
        when(repository.findLevel(4L, 60)).thenReturn(2);
        when(repository.findNextRequiredExp(4L, 2)).thenReturn(120);

        WorldGrowthResponse response = service.applyMissionCompletion(
                9L, MissionCategory.LEARNING, 2);

        assertThat(response.objectCode()).isEqualTo("BOOKSHELF");
        assertThat(response.awardedExp()).isEqualTo(20);
        assertThat(response.previousLevel()).isEqualTo(1);
        assertThat(response.currentLevel()).isEqualTo(2);
        assertThat(response.currentExp()).isEqualTo(60);
        assertThat(response.levelUp()).isTrue();
        assertThat(response.rewardApplied()).isTrue();
        verify(repository).upsertProgress(9L, 4L, 60, 2);
    }

    @Test
    void treatsMissingProgressAsLevelOneZeroExp() {
        when(repository.findProgressForUpdate(9L, 4L)).thenReturn(Optional.empty());
        when(repository.findLevel(4L, 10)).thenReturn(1);
        when(repository.findNextRequiredExp(4L, 1)).thenReturn(50);

        WorldGrowthResponse response = service.applyMissionCompletion(
                9L, MissionCategory.LEARNING, 1);

        assertThat(response.currentExp()).isEqualTo(10);
        assertThat(response.currentLevel()).isEqualTo(1);
        assertThat(response.levelUp()).isFalse();
    }

    @Test
    void returnsCurrentStateWithoutApplyingDuplicateReward() {
        when(repository.findProgressForUpdate(9L, 4L))
                .thenReturn(Optional.of(new UserWorldProgress(350, 5)));
        when(repository.findNextRequiredExp(4L, 5)).thenReturn(null);

        WorldGrowthResponse response = service.currentWithoutReward(
                9L, MissionCategory.LEARNING);

        assertThat(response.awardedExp()).isZero();
        assertThat(response.currentLevel()).isEqualTo(5);
        assertThat(response.nextLevelRequiredExp()).isNull();
        assertThat(response.rewardApplied()).isFalse();
    }
}
