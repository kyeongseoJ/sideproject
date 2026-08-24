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

final class InvalidLoginIdException extends UserDomainException {
    InvalidLoginIdException() {
        super("아이디는 영문 소문자, 숫자, 밑줄로 4자 이상 20자 이하로 입력해 주세요.");
    }
}

final class InvalidPasswordException extends UserDomainException {
    InvalidPasswordException() {
        super("비밀번호는 영문과 숫자를 포함해 8자 이상 64자 이하로 입력해 주세요.");
    }
}

final class DuplicateLoginIdException extends UserDomainException {
    DuplicateLoginIdException() {
        super("이미 사용 중인 아이디입니다.");
    }
}

final class InvalidCredentialsException extends UserDomainException {
    InvalidCredentialsException() {
        super("아이디 또는 비밀번호가 올바르지 않습니다.");
    }
}
