package com.novelty.mission;

public record MissionSettingsResponse(
        AvailableTime availableTime,
        int dailyMissionLimit) {

    public MissionSettingsResponse {
        if (availableTime == null || dailyMissionLimit < 1 || dailyMissionLimit > 3) {
            throw new IllegalArgumentException("mission settings are invalid.");
        }
    }
}
