package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.mockito.stubbing.Answer;

/** Temporary end-to-end state harness. Remove after the release verification run. */
class TemporaryTwentyMissionHarnessTest {

    @Test
    void threeUsersCompleteTwentyMissionsAndReachEveryFiveMissionMilestone() {
        MissionRepository repository = mock(MissionRepository.class);
        Map<Long, UserMissionVector> vectors = new HashMap<>();
        for (long userId = 1; userId <= 3; userId++) {
            vectors.put(userId, new UserMissionVector(-1, -1, 0, 0, 0));
        }
        when(repository.findUserVector(anyLong()))
                .thenAnswer((Answer<Optional<UserMissionVector>>) invocation ->
                        Optional.of(vectors.get(invocation.getArgument(0, Long.class))));
        when(repository.findById(anyLong())).thenReturn(Optional.of(new Mission(
                1L, "harness mission", "harness", MissionCategory.OUTDOOR,
                2, 15, 1, 1, 2, 2, true, MissionSourceType.BASE)));
        doAnswer(invocation -> {
            vectors.put(
                    invocation.getArgument(0, Long.class),
                    invocation.getArgument(1, UserMissionVector.class));
            return null;
        }).when(repository).updateUserVector(anyLong(), org.mockito.ArgumentMatchers.any());

        MissionProfileUpdater updater = new MissionProfileUpdater(repository);
        for (long userId = 1; userId <= 3; userId++) {
            for (int completion = 1; completion <= 20; completion++) {
                MissionProfileUpdater.CompletionUpdate update = updater.recordCompletion(userId, 1L);
                assertThat(update.vector().completedMissionCount()).isEqualTo(completion);
                assertThat(update.milestone()).isEqualTo(completion % 5 == 0 ? completion : 0);
                assertThat(update.personalityUpdated()).isEqualTo(completion <= 2);
            }
            assertThat(vectors.get(userId).completedMissionCount()).isEqualTo(20);
        }
    }
}
