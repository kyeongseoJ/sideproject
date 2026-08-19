package com.novelty.mission;

import java.time.OffsetDateTime;

public record MissionStatusEvent(
        long missionId,
        String category,
        MissionStatus status,
        OffsetDateTime occurredAt) {
}
