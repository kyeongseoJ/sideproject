package com.novelty.mission;

import java.time.LocalDate;
import java.util.List;

public record MissionTodayResponse(
        LocalDate serviceDate,
        MissionSettingsResponse settings,
        int completedToday,
        int remainingSlots,
        List<UserMissionResponse> activeMissions,
        List<UserMissionResponse> candidates) {

    public MissionTodayResponse {
        activeMissions = List.copyOf(activeMissions);
        candidates = List.copyOf(candidates);
    }
}
