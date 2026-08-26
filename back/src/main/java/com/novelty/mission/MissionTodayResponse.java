package com.novelty.mission;

import java.time.LocalDate;
import java.util.List;

public record MissionTodayResponse(
        LocalDate serviceDate,
        int completedToday,
        List<UserMissionResponse> activeMissions,
        List<UserMissionResponse> candidates) {

    public MissionTodayResponse {
        activeMissions = List.copyOf(activeMissions);
        candidates = List.copyOf(candidates);
    }
}
