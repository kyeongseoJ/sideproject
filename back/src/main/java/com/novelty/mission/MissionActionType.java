package com.novelty.mission;

public enum MissionActionType {
    EXPLORE,
    OBSERVE,
    CREATE,
    CONNECT,
    ORGANIZE,
    EXERCISE,
    ASK,
    PRACTICE,
    TASTE,
    LISTEN;

    static MissionActionType defaultFor(MissionCategory category) {
        return switch (category) {
            case MOVEMENT -> EXERCISE;
            case CREATIVE -> CREATE;
            case FOOD -> TASTE;
            case LEARNING -> PRACTICE;
            case SOCIAL -> CONNECT;
            case OUTDOOR -> EXPLORE;
            case ORGANIZING -> ORGANIZE;
            case CULTURE -> LISTEN;
        };
    }
}
