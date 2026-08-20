package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;

import org.junit.jupiter.api.Test;

class MissionLlmGenerationServiceTest {

    @Test
    void doesNotClaimMilestoneWhenOpenAiIsNotConfigured() {
        MissionRepository repository = mock(MissionRepository.class);
        MissionContentGenerator generator = mock(MissionContentGenerator.class);
        when(generator.isAvailable()).thenReturn(false);
        MissionLlmGenerationService service = new MissionLlmGenerationService(
                repository, generator, new MissionSimilarityPolicy());

        String status = service.generateAtMilestone(
                1L, 5, new UserMissionVector(1, 1, 2, 0, 5));

        assertThat(status).isEqualTo("NOT_CONFIGURED");
        verify(repository, never()).claimGeneration(
                org.mockito.ArgumentMatchers.anyLong(),
                org.mockito.ArgumentMatchers.anyInt(),
                org.mockito.ArgumentMatchers.anyString());
    }

    @Test
    void similarGenerationIsRejectedBeforeInsert() {
        MissionRepository repository = mock(MissionRepository.class);
        MissionContentGenerator generator = mock(MissionContentGenerator.class);
        Mission existing = new Mission(
                3L, "낯선 음악 듣기", "새로운 장르 음악을 끝까지 들어 보세요",
                MissionCategory.CULTURE, 1, 10, -1, -1, 0, 2, true, MissionSourceType.BASE);
        GeneratedMission generated = new GeneratedMission(
                "낯선 음악 들어보기", "새로운 장르의 음악을 끝까지 들어 보세요",
                MissionCategory.CULTURE, 1, 10, -1, -1, 0, 2);
        when(generator.isAvailable()).thenReturn(true);
        when(generator.modelName()).thenReturn("test-model");
        when(repository.claimGeneration(1L, 5, "test-model")).thenReturn(true);
        when(repository.findAllEnabled()).thenReturn(List.of(existing));
        when(generator.generate(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any()))
                .thenReturn(generated);
        MissionLlmGenerationService service = new MissionLlmGenerationService(
                repository, generator, new MissionSimilarityPolicy());

        String status = service.generateAtMilestone(
                1L, 5, new UserMissionVector(1, 1, 2, 0, 5));

        assertThat(status).isEqualTo("REJECTED_SIMILAR");
        verify(repository).failGeneration(1L, 5, "TOO_SIMILAR");
        verify(repository, never()).insertGenerated(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void createsValidatedDistantMissionOnceAtMilestone() {
        MissionRepository repository = mock(MissionRepository.class);
        MissionContentGenerator generator = mock(MissionContentGenerator.class);
        GeneratedMission generated = new GeneratedMission(
                "새로운 야외 활동", "익숙하지 않은 야외 활동을 짧게 시도해 보세요",
                MissionCategory.OUTDOOR, 2, 15, 1, 1, 2, 2);
        when(generator.isAvailable()).thenReturn(true);
        when(generator.modelName()).thenReturn("test-model");
        when(repository.claimGeneration(1L, 5, "test-model")).thenReturn(true);
        when(repository.findAllEnabled()).thenReturn(List.of());
        when(generator.generate(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any()))
                .thenReturn(generated);
        when(repository.insertGenerated(generated)).thenReturn(77L);

        String status = new MissionLlmGenerationService(
                repository, generator, new MissionSimilarityPolicy())
                .generateAtMilestone(1L, 5, new UserMissionVector(-1, -1, 0, 0, 5));

        assertThat(status).isEqualTo("CREATED");
        verify(repository).completeGeneration(1L, 5, 77L);
    }

    @Test
    void doesNotGenerateWhenMilestoneWasAlreadyClaimed() {
        MissionRepository repository = mock(MissionRepository.class);
        MissionContentGenerator generator = mock(MissionContentGenerator.class);
        when(generator.isAvailable()).thenReturn(true);
        when(generator.modelName()).thenReturn("test-model");
        when(repository.claimGeneration(1L, 5, "test-model")).thenReturn(false);

        String status = new MissionLlmGenerationService(
                repository, generator, new MissionSimilarityPolicy())
                .generateAtMilestone(1L, 5, new UserMissionVector(-1, -1, 0, 0, 5));

        assertThat(status).isEqualTo("ALREADY_PROCESSED");
        verify(generator, never()).generate(
                org.mockito.ArgumentMatchers.any(),
                org.mockito.ArgumentMatchers.any());
    }

    @Test
    void rejectsMissionThatIsTooCloseToPersonality() {
        MissionRepository repository = mock(MissionRepository.class);
        MissionContentGenerator generator = mock(MissionContentGenerator.class);
        GeneratedMission generated = new GeneratedMission(
                "익숙한 실내 활동", "조용한 실내에서 가볍게 정리해 보세요",
                MissionCategory.ORGANIZING, 1, 5, -1, -1, 0, 0);
        when(generator.isAvailable()).thenReturn(true);
        when(generator.modelName()).thenReturn("test-model");
        when(repository.claimGeneration(1L, 5, "test-model")).thenReturn(true);
        when(repository.findAllEnabled()).thenReturn(List.of());
        when(generator.generate(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any()))
                .thenReturn(generated);

        String status = new MissionLlmGenerationService(
                repository, generator, new MissionSimilarityPolicy())
                .generateAtMilestone(1L, 5, new UserMissionVector(-1, -1, 0, 0, 5));

        assertThat(status).isEqualTo("REJECTED_TOO_CLOSE");
        verify(repository).failGeneration(1L, 5, "TOO_CLOSE_TO_PERSONALITY");
        verify(repository, never()).insertGenerated(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void repositoryOrGeneratorFailureIsReturnedAsFailed() {
        MissionRepository repository = mock(MissionRepository.class);
        MissionContentGenerator generator = mock(MissionContentGenerator.class);
        when(generator.isAvailable()).thenReturn(true);
        when(generator.modelName()).thenReturn("test-model");
        when(repository.claimGeneration(1L, 5, "test-model"))
                .thenThrow(new IllegalStateException("database unavailable"));

        String status = new MissionLlmGenerationService(
                repository, generator, new MissionSimilarityPolicy())
                .generateAtMilestone(1L, 5, new UserMissionVector(-1, -1, 0, 0, 5));

        assertThat(status).isEqualTo("FAILED");
    }
}
