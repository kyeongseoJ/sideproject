package com.novelty.personality;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import io.swagger.v3.oas.annotations.media.Schema;

public record PersonalityAnalysisRequest(
        @Schema(
                description = "같은 분석 요청을 재시도할 때 유지하는 UUID v4 제출 식별자",
                format = "uuid",
                example = "2c3ed6f9-5780-4da8-9c73-830ce137b899")
        String submissionKey,
        @Schema(description = "최초 분석 또는 재분석 여부", example = "INITIAL")
        AnalysisMode analysisMode,
        @Schema(description = "선호 활동 공간", example = "INDOOR")
        IndoorOutdoor indoorOutdoor,
        @Schema(description = "사회적 활동 선호 수준", example = "LOW")
        SocialLevel socialLevel,
        @Schema(description = "신체 활동 수준", example = "LOW")
        PhysicalActivityLevel physicalActivityLevel,
        @Schema(description = "새로운 경험 선호 수준", example = "MEDIUM")
        NoveltyLevel noveltyLevel,
        @Schema(description = "관심 분야, 한 개 이상 세 개 이하", example = "[\"CREATIVE\", \"LEARNING\"]")
        List<Interest> interests,
        @Schema(description = "미션 수행 방식", example = "PLANNED")
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
