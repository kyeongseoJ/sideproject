package com.novelty.mission;

import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.transaction.TransactionException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import com.novelty.user.UserAuthenticationException;

@RestControllerAdvice(assignableTypes = {
        MissionController.class,
        UserMissionController.class,
        MissionSummaryController.class
})
public class MissionExceptionHandler {

    @ExceptionHandler(UserAuthenticationException.class)
    public ResponseEntity<MissionErrorResponse> handleAuthentication() {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(new MissionErrorResponse("INVALID_USER_KEY", "사용자 정보를 확인할 수 없습니다."));
    }

    @ExceptionHandler(InvalidMissionRequestException.class)
    public ResponseEntity<MissionErrorResponse> handleInvalidRequest(MissionDomainException exception) {
        return ResponseEntity.badRequest()
                .body(new MissionErrorResponse(exception.code(), exception.getMessage()));
    }

    @ExceptionHandler({
            PersonalityRequiredException.class,
            DailyLimitReachedException.class,
            ReplacementNotAvailableException.class,
            NoMissionAvailableException.class,
            InvalidMissionTransitionException.class
    })
    public ResponseEntity<MissionErrorResponse> handleConflict(MissionDomainException exception) {
        return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(new MissionErrorResponse(exception.code(), exception.getMessage()));
    }

    @ExceptionHandler({MissionNotFoundException.class, UserMissionNotFoundException.class})
    public ResponseEntity<MissionErrorResponse> handleNotFound(MissionDomainException exception) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(new MissionErrorResponse(exception.code(), exception.getMessage()));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<MissionErrorResponse> handleUnreadableRequest() {
        return ResponseEntity.badRequest()
                .body(new MissionErrorResponse("INVALID_MISSION_REQUEST", "미션 요청 형식이 올바르지 않습니다."));
    }

    @ExceptionHandler({
            DataAccessException.class,
            TransactionException.class,
            IllegalStateException.class
    })
    public ResponseEntity<MissionErrorResponse> handleDatabaseFailure() {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new MissionErrorResponse(
                        "MISSION_PROCESSING_FAILED",
                        "미션 정보를 처리하지 못했습니다. 잠시 후 다시 시도해 주세요."));
    }
}
