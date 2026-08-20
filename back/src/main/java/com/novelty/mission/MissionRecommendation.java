package com.novelty.mission;

public record MissionRecommendation(
        Mission mission,
        double personalityDistance,
        double categoryExplorationScore,
        double difficultyFitScore,
        double recommendationScore) {

    public MissionRecommendation {
        if (mission == null) {
            throw new IllegalArgumentException("mission is required.");
        }
        requireScore("personalityDistance", personalityDistance);
        requireScore("categoryExplorationScore", categoryExplorationScore);
        requireScore("difficultyFitScore", difficultyFitScore);
        requireScore("recommendationScore", recommendationScore);
    }

    private static void requireScore(String name, double value) {
        if (!Double.isFinite(value) || value < 0.0 || value > 1.0) {
            throw new IllegalArgumentException(name + " must be between zero and one.");
        }
    }
}
