package com.novelty.personality;

public enum NoveltyLevel {
    LOW(0),
    MEDIUM(1),
    HIGH(2);

    private final int score;

    NoveltyLevel(int score) {
        this.score = score;
    }

    public int score() {
        return score;
    }
}
