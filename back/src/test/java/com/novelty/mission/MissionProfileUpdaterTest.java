package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class MissionProfileUpdaterTest {

    @Test
    void everyCompletionUpdatesAllVectorAxes() {
        MissionRepository repository = mock(MissionRepository.class);
        when(repository.findUserVector(7L))
                .thenReturn(Optional.of(new UserMissionVector(-1, -1, 0, 0, 0)));
        when(repository.findById(1L)).thenReturn(Optional.of(mission(1, 1, 2, 2)));
        MissionProfileUpdater updater = new MissionProfileUpdater(repository);

        MissionProfileUpdater.CompletionUpdate result = updater.recordCompletion(7L, 1L);

        assertThat(result.personalityUpdated()).isTrue();
        assertThat(result.milestone()).isZero();
        assertThat(result.previousVector()).isEqualTo(new UserMissionVector(-1, -1, 0, 0, 0));
        ArgumentCaptor<UserMissionVector> vector = ArgumentCaptor.forClass(UserMissionVector.class);
        verify(repository).updateUserVector(org.mockito.ArgumentMatchers.eq(7L), vector.capture());
        assertThat(vector.getValue()).isEqualTo(new UserMissionVector(0, 0, 1, 1, 1));
        verify(repository).updatePersonalityClassification(
                7L, "BALANCED_COORDINATOR", 1);
    }

    @Test
    void fifthCompletionKeepsGenerationMilestoneSeparateFromPersonalityUpdate() {
        MissionRepository repository = mock(MissionRepository.class);
        UserMissionVector current = new UserMissionVector(-1, -1, 0, 0, 4);
        when(repository.findUserVector(7L)).thenReturn(Optional.of(current));
        when(repository.findById(1L)).thenReturn(Optional.of(mission(1, 1, 2, 2)));

        MissionProfileUpdater.CompletionUpdate result = new MissionProfileUpdater(repository)
                .recordCompletion(7L, 1L);

        assertThat(result.personalityUpdated()).isTrue();
        assertThat(result.vector()).isEqualTo(new UserMissionVector(0, 0, 1, 1, 5));
        assertThat(result.milestone()).isEqualTo(5);
    }

    @Test
    void matchingMissionIsRecordedWithoutReportingAVisibleDelta() {
        MissionRepository repository = mock(MissionRepository.class);
        when(repository.findUserVector(7L))
                .thenReturn(Optional.of(new UserMissionVector(1, 1, 2, 2, 1)));
        when(repository.findById(1L)).thenReturn(Optional.of(mission(1, 1, 2, 2)));

        MissionProfileUpdater.CompletionUpdate result = new MissionProfileUpdater(repository)
                .recordCompletion(7L, 1L);

        assertThat(result.personalityUpdated()).isFalse();
        assertThat(result.vector()).isEqualTo(new UserMissionVector(1, 1, 2, 2, 2));
        verify(repository).updatePersonalityClassification(7L, "ACTIVE_CONNECTOR", 2);
    }

    private Mission mission(int indoorOutdoor, int social, int activity, int novelty) {
        return new Mission(
                1L, "미션", "설명", MissionCategory.MOVEMENT,
                1, 10, indoorOutdoor, social, activity, novelty, true, MissionSourceType.BASE);
    }
}
