package com.novelty.personality;

import java.util.List;

public record PersonalityAnalysis(
        PersonalityType type,
        IndoorOutdoor indoorOutdoor,
        SocialLevel socialLevel,
        PhysicalActivityLevel physicalActivityLevel,
        NoveltyLevel noveltyLevel,
        int indoorOutdoorScore,
        int socialLevelScore,
        int physicalActivityLevelScore,
        int noveltyLevelScore,
        List<Interest> interests,
        ExecutionStyle executionStyle,
        String analysisVersion) {

    public static final String CURRENT_VERSION = "PERSONALITY_V2";

    public PersonalityAnalysis {
        interests = List.copyOf(interests);
    }
}
