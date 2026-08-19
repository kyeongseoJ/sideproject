package com.novelty.mission;

public record Mission(
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
        MissionSourceType sourceType) {

    public MissionCandidate candidate() {
        return new MissionCandidate(id, category.name());
    }
}
