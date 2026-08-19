package com.novelty.user;

import java.time.OffsetDateTime;
import java.util.List;

import com.novelty.personality.ExecutionStyle;
import com.novelty.personality.IndoorOutdoor;
import com.novelty.personality.Interest;
import com.novelty.personality.NoveltyLevel;
import com.novelty.personality.PersonalityAnalysis;
import com.novelty.personality.PhysicalActivityLevel;
import com.novelty.personality.SocialLevel;

public record UserPersonalityResponse(
        String typeCode,
        String typeName,
        String summary,
        IndoorOutdoor indoorOutdoor,
        int indoorOutdoorScore,
        SocialLevel socialLevel,
        int socialScore,
        PhysicalActivityLevel physicalActivityLevel,
        int physicalActivityScore,
        NoveltyLevel noveltyLevel,
        int noveltyScore,
        ExecutionStyle executionStyle,
        List<Interest> interests,
        String analysisVersion,
        OffsetDateTime analyzedAt) {

    public UserPersonalityResponse {
        interests = List.copyOf(interests);
    }

    public static UserPersonalityResponse from(
            PersonalityAnalysis analysis,
            OffsetDateTime analyzedAt) {
        return new UserPersonalityResponse(
                analysis.type().name(),
                analysis.type().displayName(),
                analysis.type().summary(),
                analysis.indoorOutdoor(),
                analysis.indoorOutdoorScore(),
                analysis.socialLevel(),
                analysis.socialLevelScore(),
                analysis.physicalActivityLevel(),
                analysis.physicalActivityLevelScore(),
                analysis.noveltyLevel(),
                analysis.noveltyLevelScore(),
                analysis.executionStyle(),
                analysis.interests(),
                analysis.analysisVersion(),
                analyzedAt);
    }
}
