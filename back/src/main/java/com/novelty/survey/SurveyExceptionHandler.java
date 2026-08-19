package com.novelty.survey;

import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.transaction.TransactionException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice(assignableTypes = SurveyController.class)
public class SurveyExceptionHandler {

    @ExceptionHandler(InvalidSurveyException.class)
    public ResponseEntity<SurveyErrorResponse> handleInvalidSurvey(InvalidSurveyException exception) {
        return ResponseEntity.badRequest()
                .body(new SurveyErrorResponse("INVALID_SURVEY", exception.getMessage()));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<SurveyErrorResponse> handleUnreadableRequest() {
        return ResponseEntity.badRequest()
                .body(new SurveyErrorResponse(
                        "INVALID_SURVEY",
                        "요청 형식 또는 선택 코드가 올바르지 않습니다."));
    }

    @ExceptionHandler({DataAccessException.class, TransactionException.class})
    public ResponseEntity<SurveyErrorResponse> handleSaveFailure() {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new SurveyErrorResponse(
                        "SURVEY_SAVE_FAILED",
                        "선택을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요."));
    }
}
