package com.novelty.personality;

public final class InvalidPersonalityAnswersException extends RuntimeException {

    private final PersonalityValidationError error;

    public InvalidPersonalityAnswersException(PersonalityValidationError error, String message) {
        super(message);
        this.error = error;
    }

    public PersonalityValidationError error() {
        return error;
    }
}
