package com.novelty.mission;

import java.util.List;

import org.springframework.stereotype.Component;

import com.novelty.personality.IndoorOutdoor;
import com.novelty.personality.PersonalityType;
import com.novelty.personality.SocialLevel;

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
            return new CompletionUpdate(counted, false, 0, null);
        }

        List<Mission> recent = missionRepository.findRecentCompleted(userId, UPDATE_INTERVAL);
        if (recent.size() != UPDATE_INTERVAL) {
            throw new IllegalStateException("Recent completed mission history is inconsistent.");
        }
        UserMissionVector updated = new UserMissionVector(
                blend(current.indoorOutdoor(), average(recent, Axis.INDOOR_OUTDOOR), -1, 1),
                blend(current.socialLevel(), average(recent, Axis.SOCIAL), -1, 1),
                blend(current.activityLevel(), average(recent, Axis.ACTIVITY), 0, 2),
                blend(current.noveltyLevel(), average(recent, Axis.NOVELTY), 0, 2),
                completedCount);
        missionRepository.updateUserVector(userId, updated);
        String personalityCode = personalityType(updated).name();
        missionRepository.updatePersonalityClassification(
                userId, personalityCode, completedCount);
        return new CompletionUpdate(updated, true, completedCount, personalityCode);
    }

    private double average(List<Mission> missions, Axis axis) {
        return missions.stream().mapToInt(mission -> axis.value(mission)).average().orElse(0.0);
    }

    private int blend(int current, double observedAverage, int minimum, int maximum) {
        return Math.max(minimum, Math.min(maximum, (int) Math.round((current + observedAverage) / 2.0)));
    }

    private PersonalityType personalityType(UserMissionVector vector) {
        IndoorOutdoor indoorOutdoor = switch (vector.indoorOutdoor()) {
            case -1 -> IndoorOutdoor.INDOOR;
            case 0 -> IndoorOutdoor.MIXED;
            case 1 -> IndoorOutdoor.OUTDOOR;
            default -> throw new IllegalArgumentException("Invalid indoor/outdoor score.");
        };
        SocialLevel socialLevel = switch (vector.socialLevel()) {
            case -1 -> SocialLevel.LOW;
            case 0 -> SocialLevel.MEDIUM;
            case 1 -> SocialLevel.HIGH;
            default -> throw new IllegalArgumentException("Invalid social score.");
        };
        return PersonalityType.from(indoorOutdoor, socialLevel);
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

    record CompletionUpdate(
            UserMissionVector vector,
            boolean personalityUpdated,
            int milestone,
            String personalityCode) {
    }
}
