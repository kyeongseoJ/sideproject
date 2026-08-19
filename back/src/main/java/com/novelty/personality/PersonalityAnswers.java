package com.novelty.personality;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public record PersonalityAnswers(
        IndoorOutdoor indoorOutdoor,
        SocialLevel socialLevel,
        PhysicalActivityLevel physicalActivityLevel,
        NoveltyLevel noveltyLevel,
        List<Interest> interests,
        ExecutionStyle executionStyle) {

    public PersonalityAnswers {
        if (interests != null) {
            interests = Collections.unmodifiableList(new ArrayList<>(interests));
        }
    }
}
