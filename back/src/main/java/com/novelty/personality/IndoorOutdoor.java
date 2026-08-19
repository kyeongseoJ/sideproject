package com.novelty.personality;

public enum IndoorOutdoor {
    INDOOR(-1),
    MIXED(0),
    OUTDOOR(1);

    private final int score;

    IndoorOutdoor(int score) {
        this.score = score;
    }

    public int score() {
        return score;
    }
}
