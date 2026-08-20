package com.novelty.mission;

public record MissionSettingsRequest(
        AvailableTime availableTime,
        int dailyMissionLimit) {
}
