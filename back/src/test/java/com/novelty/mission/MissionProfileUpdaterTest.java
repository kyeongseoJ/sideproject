package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class MissionProfileUpdaterTest {

    @Test
    void fifthCompletionUpdatesAllVectorAxes() {
        MissionRepository repository = mock(MissionRepository.class);
        when(repository.findUserVector(7L))
                .thenReturn(Optional.of(new UserMissionVector(-1, -1, 0, 0, 4)));
        when(repository.findRecentCompleted(7L, 5)).thenReturn(List.of(
                mission(1, 1, 2, 2),
                mission(1, 1, 2, 2),
                mission(1, 1, 2, 2),
                mission(1, 1, 2, 2),
                mission(1, 1, 2, 2)));
        MissionProfileUpdater updater = new MissionProfileUpdater(repository);

        MissionProfileUpdater.CompletionUpdate result = updater.recordCompletion(7L);

        assertThat(result.personalityUpdated()).isTrue();
        assertThat(result.milestone()).isEqualTo(5);
        ArgumentCaptor<UserMissionVector> vector = ArgumentCaptor.forClass(UserMissionVector.class);
        verify(repository).updateUserVector(org.mockito.ArgumentMatchers.eq(7L), vector.capture());
        assertThat(vector.getValue()).isEqualTo(new UserMissionVector(0, 0, 1, 1, 5));
    }

    @Test
    void nonMilestoneOnlyIncrementsCompletionCount() {
        MissionRepository repository = mock(MissionRepository.class);
        UserMissionVector current = new UserMissionVector(1, 0, 2, 1, 5);
        when(repository.findUserVector(7L)).thenReturn(Optional.of(current));

        MissionProfileUpdater.CompletionUpdate result = new MissionProfileUpdater(repository)
                .recordCompletion(7L);

        assertThat(result.personalityUpdated()).isFalse();
        assertThat(result.vector()).isEqualTo(new UserMissionVector(1, 0, 2, 1, 6));
    }

    private Mission mission(int indoorOutdoor, int social, int activity, int novelty) {
        return new Mission(
                1L, "미션", "설명", MissionCategory.MOVEMENT,
                1, 10, indoorOutdoor, social, activity, novelty, true, MissionSourceType.BASE);
    }
}
