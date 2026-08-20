package com.novelty.mission;

import java.time.OffsetDateTime;

public record UserMissionResponse(
        long userMissionId,
        long missionId,
        String title,
        String description,
        MissionCategory category,
        int difficulty,
        int estimatedMinutes,
        int indoorOutdoor,
        int socialLevel,
        int activityLevel,
        int noveltyLevel,
        MissionSourceType sourceType,
        double personalityDistance,
        double recommendationScore,
        MissionStatus status,
        OffsetDateTime statusAt) {
}
