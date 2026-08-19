package com.novelty.personality;

import java.time.OffsetDateTime;

record StoredPersonalitySubmission(
        long analysisId,
        AnalysisMode analysisMode,
        PersonalityAnswers answers,
        String analysisVersion,
        OffsetDateTime analyzedAt) {

    boolean matches(AnalysisMode requestedMode, PersonalityAnswers requestedAnswers) {
        return analysisMode == requestedMode
                && answers.equals(requestedAnswers)
                && PersonalityAnalysis.CURRENT_VERSION.equals(analysisVersion);
    }
}
