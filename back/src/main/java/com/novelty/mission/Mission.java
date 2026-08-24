package com.novelty.mission;

import java.util.Set;

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
        MissionActionType actionType,
        int creativityLevel,
        int unpredictabilityLevel,
        int comfortZoneDistance,
        int costLevel,
        Set<String> tags,
        boolean enabled,
        MissionSourceType sourceType) {

    public Mission(
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
        this(
                id, title, description, category, difficulty, estimatedMinutes,
                indoorOutdoor, socialLevel, activityLevel, noveltyLevel,
                category == null ? null : MissionActionType.defaultFor(category),
                category == MissionCategory.CREATIVE ? 2 : 0,
                noveltyLevel,
                noveltyLevel,
                0,
                category == null ? Set.of("UNKNOWN") : Set.of(category.name()),
                enabled,
                sourceType);
    }

    public Mission {
        if (id <= 0) {
            throw new IllegalArgumentException("mission id must be positive.");
        }
        requireText("title", title, 100);
        requireText("description", description, 500);
        if (category == null) {
            throw new IllegalArgumentException("mission category is required.");
        }
        requireRange("difficulty", difficulty, 1, 3);
        requireRange("estimatedMinutes", estimatedMinutes, 1, 180);
        requireRange("indoorOutdoor", indoorOutdoor, -1, 1);
        requireRange("socialLevel", socialLevel, -1, 1);
        requireRange("activityLevel", activityLevel, 0, 2);
        requireRange("noveltyLevel", noveltyLevel, 0, 2);
        if (actionType == null) {
            throw new IllegalArgumentException("mission action type is required.");
        }
        requireRange("creativityLevel", creativityLevel, 0, 2);
        requireRange("unpredictabilityLevel", unpredictabilityLevel, 0, 2);
        requireRange("comfortZoneDistance", comfortZoneDistance, 0, 2);
        requireRange("costLevel", costLevel, 0, 2);
        if (tags == null || tags.isEmpty() || tags.size() > 10) {
            throw new IllegalArgumentException("mission tags are invalid.");
        }
        for (String tag : tags) {
            if (tag == null || !tag.matches("[A-Z0-9_]{1,30}")) {
                throw new IllegalArgumentException("mission tag is invalid.");
            }
        }
        tags = Set.copyOf(tags);
        if (sourceType == null) {
            throw new IllegalArgumentException("mission source type is required.");
        }
    }

    public MissionCandidate candidate() {
        return new MissionCandidate(id, category.name());
    }

    public int durationLevel() {
        if (estimatedMinutes <= 10) {
            return 0;
        }
        if (estimatedMinutes <= 30) {
            return 1;
        }
        return 2;
    }

    private static void requireText(String name, String value, int maximumLength) {
        if (value == null || value.isBlank() || value.length() > maximumLength) {
            throw new IllegalArgumentException(name + " is invalid.");
        }
    }

    private static void requireRange(String name, int value, int minimum, int maximum) {
        if (value < minimum || value > maximum) {
            throw new IllegalArgumentException(name + " is outside its allowed range.");
        }
    }
}
