package com.novelty.mission;

import java.util.List;

public interface MissionContentGenerator {

    boolean isAvailable();

    String modelName();

    GeneratedMission generate(UserMissionVector userVector, List<Mission> existingMissions);
}
