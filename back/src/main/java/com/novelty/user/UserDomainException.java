package com.novelty.user;

abstract class UserDomainException extends RuntimeException {

    UserDomainException(String message) {
        super(message);
    }
}

final class InvalidUserKeyException extends UserDomainException {
    InvalidUserKeyException() {
        super("사용자 정보를 확인할 수 없습니다.");
    }
}

final class InvalidNicknameException extends UserDomainException {
    InvalidNicknameException() {
        super("닉네임은 한글, 영문, 숫자로 1자 이상 12자 이하로 입력해 주세요.");
    }
}

final class BannedNicknameException extends UserDomainException {
    BannedNicknameException() {
        super("사용할 수 없는 닉네임입니다.");
    }
}

final class DuplicateNicknameException extends UserDomainException {
    DuplicateNicknameException() {
        super("이미 사용 중인 닉네임입니다.");
    }
}

final class NicknameGenerationException extends UserDomainException {
    NicknameGenerationException() {
        super("초기 닉네임을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.");
    }
}
