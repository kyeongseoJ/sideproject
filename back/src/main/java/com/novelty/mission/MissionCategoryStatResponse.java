package com.novelty.mission;

import java.time.OffsetDateTime;

public record MissionCategoryStatResponse(
        MissionCategory category,
        int completedCount,
        OffsetDateTime lastCompletedAt) {
}
