package com.novelty.user;

import io.swagger.v3.oas.annotations.media.Schema;

public record AccountLoginRequest(
        @Schema(example = "novelty_user") String loginId,
        @Schema(example = "Novelty123", format = "password") String password) {
}
