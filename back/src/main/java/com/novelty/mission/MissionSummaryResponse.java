package com.novelty.mission;

import java.util.List;

public record MissionSummaryResponse(
        int completedMissionCount,
        int lastPersonalityAdaptedCount,
        String personalityCode,
        List<MissionCategoryStatResponse> categoryStats) {

    public MissionSummaryResponse {
        categoryStats = List.copyOf(categoryStats);
    }
}
