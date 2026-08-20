package com.novelty.mission;

public record MissionCompletionEffectResponse(
        MissionSummaryResponse summary,
        boolean personalityUpdated,
        int milestone,
        String llmGenerationStatus) {
}
