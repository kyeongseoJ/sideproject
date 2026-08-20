package com.novelty.mission;

public record UserMissionActionResponse(
        UserMissionResponse mission,
        MissionTodayResponse today,
        boolean idempotent,
        MissionCompletionEffectResponse completion) {

    public UserMissionActionResponse(
            UserMissionResponse mission,
            MissionTodayResponse today,
            boolean idempotent) {
        this(mission, today, idempotent, null);
    }
}
