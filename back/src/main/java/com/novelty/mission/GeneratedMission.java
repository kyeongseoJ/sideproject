package com.novelty.mission;

import java.util.Set;

public record GeneratedMission(
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
        Set<String> tags) {

    public GeneratedMission(
            String title,
            String description,
            MissionCategory category,
            int difficulty,
            int estimatedMinutes,
            int indoorOutdoor,
            int socialLevel,
            int activityLevel,
            int noveltyLevel) {
        this(
                title, description, category, difficulty, estimatedMinutes,
                indoorOutdoor, socialLevel, activityLevel, noveltyLevel,
                category == null ? null : MissionActionType.defaultFor(category),
                category == MissionCategory.CREATIVE ? 2 : 0,
                noveltyLevel,
                noveltyLevel,
                0,
                category == null ? Set.of("UNKNOWN") : Set.of(category.name()));
    }

    public GeneratedMission {
        if (title == null || title.isBlank() || title.length() > 100) {
            throw new IllegalArgumentException("Generated mission title is invalid.");
        }
        if (description == null || description.isBlank() || description.length() > 500) {
            throw new IllegalArgumentException("Generated mission description is invalid.");
        }
        if (category == null) {
            throw new IllegalArgumentException("Generated mission category is required.");
        }
        requireRange(difficulty, 1, 3);
        requireRange(estimatedMinutes, 1, 180);
        requireRange(indoorOutdoor, -1, 1);
        requireRange(socialLevel, -1, 1);
        requireRange(activityLevel, 0, 2);
        requireRange(noveltyLevel, 0, 2);
        if (actionType == null) {
            throw new IllegalArgumentException("Generated mission action type is required.");
        }
        requireRange(creativityLevel, 0, 2);
        requireRange(unpredictabilityLevel, 0, 2);
        requireRange(comfortZoneDistance, 0, 2);
        requireRange(costLevel, 0, 2);
        if (tags == null || tags.isEmpty() || tags.size() > 10) {
            throw new IllegalArgumentException("Generated mission tags are invalid.");
        }
        for (String tag : tags) {
            if (tag == null || !tag.matches("[A-Z0-9_]{1,30}")) {
                throw new IllegalArgumentException("Generated mission tag is invalid.");
            }
        }
        tags = Set.copyOf(tags);
    }

    private static void requireRange(int value, int minimum, int maximum) {
        if (value < minimum || value > maximum) {
            throw new IllegalArgumentException("Generated mission vector is outside its allowed range.");
        }
    }
}
