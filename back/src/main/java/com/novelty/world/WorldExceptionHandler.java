package com.novelty.world;

import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.TransactionException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import com.novelty.user.UserAuthenticationException;

@RestControllerAdvice(assignableTypes = WorldController.class)
public class WorldExceptionHandler {

    @ExceptionHandler(UserAuthenticationException.class)
    public ResponseEntity<WorldErrorResponse> handleAuthentication() {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(new WorldErrorResponse("INVALID_USER_KEY", "사용자 정보를 확인할 수 없습니다."));
    }

    @ExceptionHandler({
            DataAccessException.class,
            TransactionException.class,
            IllegalStateException.class
    })
    public ResponseEntity<WorldErrorResponse> handleProcessingFailure() {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new WorldErrorResponse(
                        "WORLD_PROCESSING_FAILED",
                        "월드 정보를 처리하지 못했습니다. 잠시 후 다시 시도해 주세요."));
    }
}
