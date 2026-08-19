package com.novelty.mission;

public enum AvailableTime {
    QUICK(5),
    SHORT(15),
    MEDIUM(30),
    LONG(60);

    private final int maximumMinutes;

    AvailableTime(int maximumMinutes) {
        this.maximumMinutes = maximumMinutes;
    }

    public int maximumMinutes() {
        return maximumMinutes;
    }
}
