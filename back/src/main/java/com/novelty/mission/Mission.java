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
        if (sourceType == null) {
            throw new IllegalArgumentException("mission source type is required.");
        }
    }

    public MissionCandidate candidate() {
        return new MissionCandidate(id, category.name());
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
