package com.novelty.world;

public record WorldGrowthResponse(
        String objectCode,
        String categoryCode,
        int awardedExp,
        int previousLevel,
        int currentLevel,
        int currentExp,
        Integer nextLevelRequiredExp,
        boolean levelUp,
        boolean rewardApplied) {
}
