package com.novelty.personality;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public record PersonalityAnalysisRequest(
        String submissionKey,
        AnalysisMode analysisMode,
        IndoorOutdoor indoorOutdoor,
        SocialLevel socialLevel,
        PhysicalActivityLevel physicalActivityLevel,
        NoveltyLevel noveltyLevel,
        List<Interest> interests,
        ExecutionStyle executionStyle) {

    public PersonalityAnalysisRequest {
        if (interests != null) {
            interests = Collections.unmodifiableList(new ArrayList<>(interests));
        }
    }

    PersonalityAnswers toAnswers() {
        return new PersonalityAnswers(
                indoorOutdoor,
                socialLevel,
                physicalActivityLevel,
                noveltyLevel,
                interests,
                executionStyle);
    }
}
