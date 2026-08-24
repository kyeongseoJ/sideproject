package com.novelty.mission;

import com.novelty.world.WorldGrowthResponse;

public record MissionCompletionEffectResponse(
        MissionSummaryResponse summary,
        boolean personalityUpdated,
        MissionPersonalityChangeResponse personalityChange,
        int milestone,
        String llmGenerationStatus,
        WorldGrowthResponse worldGrowth) {
}
