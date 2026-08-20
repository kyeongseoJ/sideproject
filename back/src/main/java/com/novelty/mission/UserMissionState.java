package com.novelty.mission;

import java.time.LocalDate;

record UserMissionState(
        long userMissionId,
        long missionId,
        MissionCategory category,
        MissionStatus status,
        LocalDate serviceDate,
        Integer dailySlotNo) {
}
