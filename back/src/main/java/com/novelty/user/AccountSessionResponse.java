package com.novelty.user;

import io.swagger.v3.oas.annotations.media.Schema;

public record AccountSessionResponse(
        @Schema(example = "7") long userId,
        @Schema(description = "이후 X-User-Key 요청과 Client 캐시에 사용할 사용자 키") String userKey,
        @Schema(example = "노벨티07QK") String nickname,
        boolean personalityCompleted) {

    @Override
    public String toString() {
        return "AccountSessionResponse[userId=" + userId
                + ", userKey=<redacted>, nickname=" + nickname
                + ", personalityCompleted=" + personalityCompleted + "]";
    }
}
