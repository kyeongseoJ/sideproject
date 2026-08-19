package com.novelty.mission;

public record MissionResponse(
        long id,
        String title,
        String description,
        MissionCategory category,
        int difficulty,
        int estimatedMinutes,
        int indoorOutdoor,
        int socialLevel,
        int activityLevel,
        int noveltyLevel,
        boolean enabled,
        double personalityDistance,
        String status) {

    static MissionResponse shown(Mission mission, double distance) {
        return new MissionResponse(
                mission.id(),
                mission.title(),
                mission.description(),
                mission.category(),
                mission.difficulty(),
                mission.estimatedMinutes(),
                mission.indoorOutdoor(),
                mission.socialLevel(),
                mission.activityLevel(),
                mission.noveltyLevel(),
                mission.enabled(),
                distance,
                MissionStatus.SHOWN.name());
    }
}
