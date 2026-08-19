package com.novelty.user;

public record UserProfileResponse(
        long userId,
        String nickname,
        boolean personalityCompleted,
        UserPersonalityResponse personality) {

    static UserProfileResponse from(UserAccount user) {
        return new UserProfileResponse(
                user.userId(),
                user.nickname(),
                user.personalityCompleted(),
                null);
    }

    static UserProfileResponse from(
            UserAccount user,
            UserPersonalityResponse personality) {
        return new UserProfileResponse(
                user.userId(),
                user.nickname(),
                personality != null,
                personality);
    }
}
