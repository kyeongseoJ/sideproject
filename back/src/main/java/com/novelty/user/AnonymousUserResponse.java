package com.novelty.user;

import io.swagger.v3.oas.annotations.media.Schema;

public record AnonymousUserResponse(
        @Schema(example = "7")
        long userId,
        @Schema(description = "브라우저 또는 앱 캐시에 한 번만 저장할 사용자 키")
        String userKey,
        @Schema(example = "노벨티07QK")
        String nickname,
        boolean personalityCompleted) {

    @Override
    public String toString() {
        return "AnonymousUserResponse[userId="
                + userId
                + ", userKey=<redacted>, nickname="
                + nickname
                + ", personalityCompleted="
                + personalityCompleted
                + "]";
    }
}
