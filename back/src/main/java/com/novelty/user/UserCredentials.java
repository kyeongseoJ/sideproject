package com.novelty.user;

record UserCredentials(
        long userId,
        String passwordHash,
        String nickname,
        boolean personalityCompleted) {
}
