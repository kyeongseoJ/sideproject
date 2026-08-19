package com.novelty.user;

import io.swagger.v3.oas.annotations.media.Schema;

public record NicknameUpdateRequest(
        @Schema(example = "새로운닉네임")
        String nickname) {
}
