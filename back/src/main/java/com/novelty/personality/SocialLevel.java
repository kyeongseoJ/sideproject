package com.novelty.personality;

public enum SocialLevel {
    LOW(-1),
    MEDIUM(0),
    HIGH(1);

    private final int score;

    SocialLevel(int score) {
        this.score = score;
    }

    public int score() {
        return score;
    }
}
