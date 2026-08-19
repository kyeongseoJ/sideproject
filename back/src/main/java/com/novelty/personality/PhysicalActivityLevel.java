package com.novelty.personality;

public enum PhysicalActivityLevel {
    LOW(0),
    MEDIUM(1),
    HIGH(2);

    private final int score;

    PhysicalActivityLevel(int score) {
        this.score = score;
    }

    public int score() {
        return score;
    }
}
