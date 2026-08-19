package com.novelty.mission;

public record MissionStatusResponse(
        long missionId,
        String status,
        String displayStatus,
        int completedMissionCount,
        boolean personalityUpdated,
        String llmGenerationStatus) {
}
