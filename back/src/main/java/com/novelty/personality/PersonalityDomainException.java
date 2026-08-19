package com.novelty.personality;

abstract class PersonalityDomainException extends RuntimeException {

    private final String code;

    PersonalityDomainException(String code, String message) {
        super(message);
        this.code = code;
    }

    String code() {
        return code;
    }
}

final class InvalidSubmissionKeyException extends PersonalityDomainException {

    InvalidSubmissionKeyException() {
        super("INVALID_SUBMISSION_KEY", "제출 식별자가 없거나 올바르지 않습니다.");
    }
}

final class PersonalityAlreadyAnalyzedException extends PersonalityDomainException {

    PersonalityAlreadyAnalyzedException() {
        super("PERSONALITY_ALREADY_ANALYZED", "이미 최초 성향 분석을 완료했습니다.");
    }
}

final class PersonalityNotAnalyzedException extends PersonalityDomainException {

    PersonalityNotAnalyzedException() {
        super("PERSONALITY_NOT_ANALYZED", "최초 성향 분석을 먼저 완료해야 합니다.");
    }
}

final class SubmissionKeyConflictException extends PersonalityDomainException {

    SubmissionKeyConflictException() {
        super("SUBMISSION_KEY_CONFLICT", "같은 제출 식별자에 다른 답변을 사용할 수 없습니다.");
    }
}
