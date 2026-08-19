package com.novelty.personality;

import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.transaction.TransactionException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import com.novelty.user.UserAuthenticationException;

@RestControllerAdvice(assignableTypes = PersonalityController.class)
public class PersonalityExceptionHandler {

    @ExceptionHandler(InvalidSubmissionKeyException.class)
    public ResponseEntity<PersonalityErrorResponse> handleInvalidSubmissionKey(
            InvalidSubmissionKeyException exception) {
        return ResponseEntity.badRequest()
                .body(new PersonalityErrorResponse(exception.code(), exception.getMessage()));
    }

    @ExceptionHandler(InvalidPersonalityAnswersException.class)
    public ResponseEntity<PersonalityErrorResponse> handleInvalidAnswers(
            InvalidPersonalityAnswersException exception) {
        return ResponseEntity.badRequest()
                .body(new PersonalityErrorResponse(
                        "INVALID_PERSONALITY_ANSWERS",
                        exception.getMessage()));
    }

    @ExceptionHandler(UserAuthenticationException.class)
    public ResponseEntity<PersonalityErrorResponse> handleInvalidUserKey(
            UserAuthenticationException exception) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(new PersonalityErrorResponse("INVALID_USER_KEY", exception.getMessage()));
    }

    @ExceptionHandler({
            PersonalityAlreadyAnalyzedException.class,
            PersonalityNotAnalyzedException.class,
            SubmissionKeyConflictException.class
    })
    public ResponseEntity<PersonalityErrorResponse> handleConflict(
            PersonalityDomainException exception) {
        return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(new PersonalityErrorResponse(exception.code(), exception.getMessage()));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<PersonalityErrorResponse> handleUnreadableRequest() {
        return ResponseEntity.badRequest()
                .body(new PersonalityErrorResponse(
                        "INVALID_PERSONALITY_ANSWERS",
                        "요청 형식 또는 선택 코드가 올바르지 않습니다."));
    }

    @ExceptionHandler({DataAccessException.class, TransactionException.class})
    public ResponseEntity<PersonalityErrorResponse> handleSaveFailure() {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new PersonalityErrorResponse(
                        "PERSONALITY_SAVE_FAILED",
                        "성향 분석을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요."));
    }
}
