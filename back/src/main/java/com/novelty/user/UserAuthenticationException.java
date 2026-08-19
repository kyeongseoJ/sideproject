package com.novelty.user;

public class UserAuthenticationException extends RuntimeException {

    public UserAuthenticationException() {
        super("사용자 정보를 확인할 수 없습니다.");
    }
}
