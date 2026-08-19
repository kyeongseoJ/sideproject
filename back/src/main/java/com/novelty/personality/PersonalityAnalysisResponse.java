package com.novelty.personality;

import com.novelty.user.UserPersonalityResponse;

public record PersonalityAnalysisResponse(
        long analysisId,
        String status,
        UserPersonalityResponse personality) {

    public static PersonalityAnalysisResponse analyzed(
            long analysisId,
            UserPersonalityResponse personality) {
        return new PersonalityAnalysisResponse(analysisId, "ANALYZED", personality);
    }
}
