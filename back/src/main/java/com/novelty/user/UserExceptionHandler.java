package com.novelty.user;

import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.transaction.TransactionException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice(assignableTypes = UserController.class)
public class UserExceptionHandler {

    @ExceptionHandler(InvalidUserKeyException.class)
    public ResponseEntity<UserErrorResponse> handleInvalidUserKey(InvalidUserKeyException exception) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(new UserErrorResponse("INVALID_USER_KEY", exception.getMessage()));
    }

    @ExceptionHandler(InvalidNicknameException.class)
    public ResponseEntity<UserErrorResponse> handleInvalidNickname(InvalidNicknameException exception) {
        return ResponseEntity.badRequest()
                .body(new UserErrorResponse("INVALID_NICKNAME", exception.getMessage()));
    }

    @ExceptionHandler(BannedNicknameException.class)
    public ResponseEntity<UserErrorResponse> handleBannedNickname(BannedNicknameException exception) {
        return ResponseEntity.badRequest()
                .body(new UserErrorResponse("BANNED_NICKNAME", exception.getMessage()));
    }

    @ExceptionHandler(DuplicateNicknameException.class)
    public ResponseEntity<UserErrorResponse> handleDuplicateNickname(
            DuplicateNicknameException exception) {
        return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(new UserErrorResponse("DUPLICATE_NICKNAME", exception.getMessage()));
    }

    @ExceptionHandler(NicknameGenerationException.class)
    public ResponseEntity<UserErrorResponse> handleNicknameGenerationFailure(
            NicknameGenerationException exception) {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new UserErrorResponse("NICKNAME_GENERATION_FAILED", exception.getMessage()));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<UserErrorResponse> handleUnreadableRequest() {
        return ResponseEntity.badRequest()
                .body(new UserErrorResponse(
                        "INVALID_NICKNAME",
                        "닉네임 변경 요청 형식이 올바르지 않습니다."));
    }

    @ExceptionHandler({DataAccessException.class, TransactionException.class})
    public ResponseEntity<UserErrorResponse> handleSaveFailure() {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new UserErrorResponse(
                        "PROFILE_SAVE_FAILED",
                        "사용자 정보를 처리하지 못했습니다. 잠시 후 다시 시도해 주세요."));
    }
}
