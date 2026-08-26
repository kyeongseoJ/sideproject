package com.novelty.mission;

final class MissionRecommendationConfig {

    static final int CANDIDATE_LIMIT = 5;
    static final int RANKED_POOL_LIMIT = 20;
    static final int REEXPOSURE_BLOCK_DAYS = 3;
    static final int COMPLETED_HARD_BLOCK_MAX_AGE_DAYS = 3;
    static final int RECENT_EXPERIENCE_DAYS = 7;
    static final int RECENT_COMPLETED_LIMIT = 10;

    static final double RECENCY_DECAY = 0.75;
    static final double RECENT_HARD_SIMILARITY = 0.82;
    static final double FINAL_HARD_SIMILARITY = 0.75;

    static final double PERSONALITY_WEIGHT = 0.35;
    static final double NOVELTY_WEIGHT = 0.10;
    static final double CATEGORY_EXPLORATION_WEIGHT = 0.05;
    static final double RECENT_DIVERSITY_WEIGHT = 0.15;
    static final double EXPLORATION_WEIGHT = 0.15;
    static final double CONTEXT_FIT_WEIGHT = 0.20;

    static final double RECENT_SIMILARITY_PENALTY = 0.25;
    static final double REPEATED_PATTERN_PENALTY = 0.15;
    static final double REJECTION_PENALTY = 0.10;
    static final double FINAL_DIVERSITY_PENALTY = 0.35;

    static final int REPEAT_VERY_HIGH_MAX_AGE_DAYS = 7;
    static final int REPEAT_HIGH_MAX_AGE_DAYS = 14;
    static final int REPEAT_LOW_MAX_AGE_DAYS = 30;
    static final double REPEAT_VERY_HIGH_PENALTY = 0.35;
    static final double REPEAT_HIGH_PENALTY = 0.20;
    static final double REPEAT_LOW_PENALTY = 0.08;

    private MissionRecommendationConfig() {
    }
}
