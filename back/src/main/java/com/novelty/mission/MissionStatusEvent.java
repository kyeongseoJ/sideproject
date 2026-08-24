package com.novelty.mission;

import java.time.OffsetDateTime;

public record MissionStatusEvent(
        long missionId,
        String category,
        Mission mission,
        Long userMissionId,
        MissionStatus status,
        OffsetDateTime occurredAt) {

    public MissionStatusEvent(
            long missionId,
            String category,
            MissionStatus status,
            OffsetDateTime occurredAt) {
        this(missionId, category, null, null, status, occurredAt);
    }
}
