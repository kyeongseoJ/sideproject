package com.novelty.mission;

public record GeneratedMission(
        String title,
        String description,
        MissionCategory category,
        int difficulty,
        int estimatedMinutes,
        int indoorOutdoor,
        int socialLevel,
        int activityLevel,
        int noveltyLevel) {

    public GeneratedMission {
        if (title == null || title.isBlank() || title.length() > 100) {
            throw new IllegalArgumentException("Generated mission title is invalid.");
        }
        if (description == null || description.isBlank() || description.length() > 500) {
            throw new IllegalArgumentException("Generated mission description is invalid.");
        }
        requireRange(difficulty, 1, 3);
        requireRange(estimatedMinutes, 1, 180);
        requireRange(indoorOutdoor, -1, 1);
        requireRange(socialLevel, -1, 1);
        requireRange(activityLevel, 0, 2);
        requireRange(noveltyLevel, 0, 2);
    }

    private static void requireRange(int value, int minimum, int maximum) {
        if (value < minimum || value > maximum) {
            throw new IllegalArgumentException("Generated mission vector is outside its allowed range.");
        }
    }
}
