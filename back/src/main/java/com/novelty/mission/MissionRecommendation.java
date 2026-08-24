package com.novelty.mission;

public record MissionRecommendation(
        Mission mission,
        double personalityDistance,
        double categoryExplorationScore,
        double difficultyFitScore,
        double noveltyScore,
        double recentDiversityScore,
        double explorationBonus,
        double contextFitScore,
        double similarityPenalty,
        double repetitionPenalty,
        double rejectionPenalty,
        double recommendationScore) {

    public MissionRecommendation(
            Mission mission,
            double personalityDistance,
            double categoryExplorationScore,
            double difficultyFitScore,
            double recommendationScore) {
        this(
                mission,
                personalityDistance,
                categoryExplorationScore,
                difficultyFitScore,
                mission == null ? 0.0 : mission.noveltyLevel() / 2.0,
                1.0,
                1.0,
                difficultyFitScore,
                0.0,
                0.0,
                0.0,
                recommendationScore);
    }

    public MissionRecommendation {
        if (mission == null) {
            throw new IllegalArgumentException("mission is required.");
        }
        requireScore("personalityDistance", personalityDistance);
        requireScore("categoryExplorationScore", categoryExplorationScore);
        requireScore("difficultyFitScore", difficultyFitScore);
        requireScore("noveltyScore", noveltyScore);
        requireScore("recentDiversityScore", recentDiversityScore);
        requireScore("explorationBonus", explorationBonus);
        requireScore("contextFitScore", contextFitScore);
        requireScore("similarityPenalty", similarityPenalty);
        requireScore("repetitionPenalty", repetitionPenalty);
        requireScore("rejectionPenalty", rejectionPenalty);
        requireScore("recommendationScore", recommendationScore);
    }

    private static void requireScore(String name, double value) {
        if (!Double.isFinite(value) || value < 0.0 || value > 1.0) {
            throw new IllegalArgumentException(name + " must be between zero and one.");
        }
    }
}
