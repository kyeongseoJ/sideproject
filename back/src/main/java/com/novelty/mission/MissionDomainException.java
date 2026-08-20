package com.novelty.mission;

abstract class MissionDomainException extends RuntimeException {

    private final String code;

    MissionDomainException(String code, String message) {
        super(message);
        this.code = code;
    }

    String code() {
        return code;
    }
}

final class InvalidMissionRequestException extends MissionDomainException {
    InvalidMissionRequestException(String message) {
        super("INVALID_MISSION_REQUEST", message);
    }
}

final class PersonalityRequiredException extends MissionDomainException {
    PersonalityRequiredException() {
        super("PERSONALITY_REQUIRED", "미션을 받기 전에 성향 분석을 완료해 주세요.");
    }
}

final class MissionSettingsRequiredException extends MissionDomainException {
    MissionSettingsRequiredException() {
        super("MISSION_SETTINGS_REQUIRED", "미션을 받기 전에 사용 가능 시간과 하루 한도를 설정해 주세요.");
    }
}

final class MissionNotFoundException extends MissionDomainException {
    MissionNotFoundException() {
        super("MISSION_NOT_FOUND", "미션을 찾을 수 없습니다.");
    }
}

final class UserMissionNotFoundException extends MissionDomainException {
    UserMissionNotFoundException() {
        super("USER_MISSION_NOT_FOUND", "사용자 미션을 찾을 수 없습니다.");
    }
}

final class DailyLimitReachedException extends MissionDomainException {
    DailyLimitReachedException() {
        super("DAILY_LIMIT_REACHED", "오늘 수행할 수 있는 미션 수를 모두 사용했습니다.");
    }
}

final class ReplacementNotAvailableException extends MissionDomainException {
    ReplacementNotAvailableException() {
        super("REPLACEMENT_NOT_AVAILABLE", "오늘 교체할 수 있는 추천 후보가 아닙니다.");
    }
}

final class NoMissionAvailableException extends MissionDomainException {
    NoMissionAvailableException() {
        super("NO_MISSION_AVAILABLE", "현재 조건에 맞는 새 미션이 없습니다. 잠시 후 다시 시도해 주세요.");
    }
}

final class InvalidMissionTransitionException extends MissionDomainException {
    InvalidMissionTransitionException() {
        super("INVALID_MISSION_TRANSITION", "현재 미션 상태에서는 요청한 상태로 변경할 수 없습니다.");
    }
}
