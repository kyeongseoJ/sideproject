package com.novelty.world;

public record WorldObjectProgressResponse(
        String objectCode,
        String categoryCode,
        String displayName,
        int level,
        int exp,
        Integer nextLevelRequiredExp,
        int maxLevel) {
}
