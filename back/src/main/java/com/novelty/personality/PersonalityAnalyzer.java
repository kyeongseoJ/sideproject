package com.novelty.personality;

import java.util.HashSet;
import java.util.List;

public final class PersonalityAnalyzer {

    public PersonalityAnalysis analyze(PersonalityAnswers answers) {
        validate(answers);

        return new PersonalityAnalysis(
                PersonalityType.from(answers.indoorOutdoor(), answers.socialLevel()),
                answers.indoorOutdoor(),
                answers.socialLevel(),
                answers.physicalActivityLevel(),
                answers.noveltyLevel(),
                answers.indoorOutdoor().score(),
                answers.socialLevel().score(),
                answers.physicalActivityLevel().score(),
                answers.noveltyLevel().score(),
                answers.interests(),
                answers.executionStyle(),
                PersonalityAnalysis.CURRENT_VERSION);
    }

    private void validate(PersonalityAnswers answers) {
        if (answers == null) {
            throw invalid(PersonalityValidationError.ANSWERS_REQUIRED, "성향 분석 답변이 필요합니다.");
        }
        require(answers.indoorOutdoor(), PersonalityValidationError.INDOOR_OUTDOOR_REQUIRED, "활동 공간 답변이 필요합니다.");
        require(answers.socialLevel(), PersonalityValidationError.SOCIAL_LEVEL_REQUIRED, "사회적 활동 수준 답변이 필요합니다.");
        require(
                answers.physicalActivityLevel(),
                PersonalityValidationError.PHYSICAL_ACTIVITY_LEVEL_REQUIRED,
                "신체 활동 수준 답변이 필요합니다.");
        require(answers.noveltyLevel(), PersonalityValidationError.NOVELTY_LEVEL_REQUIRED, "새로움 수준 답변이 필요합니다.");
        validateInterests(answers.interests());
        require(answers.executionStyle(), PersonalityValidationError.EXECUTION_STYLE_REQUIRED, "실행 방식 답변이 필요합니다.");
    }

    private void validateInterests(List<Interest> interests) {
        if (interests == null || interests.isEmpty()) {
            throw invalid(PersonalityValidationError.INTERESTS_REQUIRED, "관심 분야를 한 개 이상 선택해야 합니다.");
        }
        if (interests.size() > 3) {
            throw invalid(PersonalityValidationError.TOO_MANY_INTERESTS, "관심 분야는 최대 세 개까지 선택할 수 있습니다.");
        }
        if (interests.stream().anyMatch(interest -> interest == null)) {
            throw invalid(PersonalityValidationError.INVALID_INTEREST, "유효하지 않은 관심 분야가 포함되어 있습니다.");
        }
        if (new HashSet<>(interests).size() != interests.size()) {
            throw invalid(PersonalityValidationError.DUPLICATE_INTERESTS, "관심 분야를 중복해서 선택할 수 없습니다.");
        }
    }

    private void require(Object value, PersonalityValidationError error, String message) {
        if (value == null) {
            throw invalid(error, message);
        }
    }

    private InvalidPersonalityAnswersException invalid(PersonalityValidationError error, String message) {
        return new InvalidPersonalityAnswersException(error, message);
    }
}
