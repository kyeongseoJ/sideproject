package com.novelty.mission;

import java.util.List;

import org.springframework.stereotype.Component;

@Component
public class MissionProfileUpdater {

    private static final int UPDATE_INTERVAL = 5;

    private final MissionRepository missionRepository;

    public MissionProfileUpdater(MissionRepository missionRepository) {
        this.missionRepository = missionRepository;
    }

    CompletionUpdate recordCompletion(long userId) {
        UserMissionVector current = missionRepository.findUserVector(userId)
                .orElseThrow(PersonalityRequiredException::new);
        int completedCount = current.completedMissionCount() + 1;
        if (completedCount % UPDATE_INTERVAL != 0) {
            UserMissionVector counted = new UserMissionVector(
                    current.indoorOutdoor(),
                    current.socialLevel(),
                    current.activityLevel(),
                    current.noveltyLevel(),
                    completedCount);
            missionRepository.updateUserVector(userId, counted);
            return new CompletionUpdate(counted, false, 0);
        }

        List<Mission> recent = missionRepository.findRecentCompleted(userId, UPDATE_INTERVAL);
        UserMissionVector updated = new UserMissionVector(
                blend(current.indoorOutdoor(), average(recent, Axis.INDOOR_OUTDOOR), -1, 1),
                blend(current.socialLevel(), average(recent, Axis.SOCIAL), -1, 1),
                blend(current.activityLevel(), average(recent, Axis.ACTIVITY), 0, 2),
                blend(current.noveltyLevel(), average(recent, Axis.NOVELTY), 0, 2),
                completedCount);
        missionRepository.updateUserVector(userId, updated);
        return new CompletionUpdate(updated, true, completedCount);
    }

    private double average(List<Mission> missions, Axis axis) {
        return missions.stream().mapToInt(mission -> axis.value(mission)).average().orElse(0.0);
    }

    private int blend(int current, double observedAverage, int minimum, int maximum) {
        return Math.max(minimum, Math.min(maximum, (int) Math.round((current + observedAverage) / 2.0)));
    }

    private enum Axis {
        INDOOR_OUTDOOR {
            @Override int value(Mission mission) { return mission.indoorOutdoor(); }
        },
        SOCIAL {
            @Override int value(Mission mission) { return mission.socialLevel(); }
        },
        ACTIVITY {
            @Override int value(Mission mission) { return mission.activityLevel(); }
        },
        NOVELTY {
            @Override int value(Mission mission) { return mission.noveltyLevel(); }
        };

        abstract int value(Mission mission);
    }

    record CompletionUpdate(UserMissionVector vector, boolean personalityUpdated, int milestone) {
    }
}
