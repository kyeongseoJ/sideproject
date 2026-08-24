package com.novelty.mission;

import org.springframework.stereotype.Component;

import com.novelty.personality.IndoorOutdoor;
import com.novelty.personality.PersonalityType;
import com.novelty.personality.SocialLevel;

@Component
public class MissionProfileUpdater {

    private static final int GENERATION_INTERVAL = 5;

    private final MissionRepository missionRepository;

    public MissionProfileUpdater(MissionRepository missionRepository) {
        this.missionRepository = missionRepository;
    }

    CompletionUpdate recordCompletion(long userId, long missionId) {
        UserMissionVector current = missionRepository.findUserVector(userId)
                .orElseThrow(PersonalityRequiredException::new);
        Mission completed = missionRepository.findById(missionId)
                .orElseThrow(() -> new IllegalStateException("Completed mission does not exist."));
        int completedCount = current.completedMissionCount() + 1;
        UserMissionVector updated = new UserMissionVector(
                blend(current.indoorOutdoor(), completed.indoorOutdoor(), -1, 1),
                blend(current.socialLevel(), completed.socialLevel(), -1, 1),
                blend(current.activityLevel(), completed.activityLevel(), 0, 2),
                blend(current.noveltyLevel(), completed.noveltyLevel(), 0, 2),
                completedCount);
        missionRepository.updateUserVector(userId, updated);
        String previousPersonalityCode = personalityType(current).name();
        String personalityCode = personalityType(updated).name();
        missionRepository.updatePersonalityClassification(
                userId, personalityCode, completedCount);
        boolean changed = !sameAxes(current, updated)
                || !previousPersonalityCode.equals(personalityCode);
        int milestone = completedCount % GENERATION_INTERVAL == 0 ? completedCount : 0;
        return new CompletionUpdate(
                current,
                updated,
                changed,
                milestone,
                previousPersonalityCode,
                personalityCode);
    }

    private int blend(int current, int observed, int minimum, int maximum) {
        return Math.max(minimum, Math.min(maximum, (int) Math.round((current + observed) / 2.0)));
    }

    private boolean sameAxes(UserMissionVector first, UserMissionVector second) {
        return first.indoorOutdoor() == second.indoorOutdoor()
                && first.socialLevel() == second.socialLevel()
                && first.activityLevel() == second.activityLevel()
                && first.noveltyLevel() == second.noveltyLevel();
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

    record CompletionUpdate(
            UserMissionVector previousVector,
            UserMissionVector vector,
            boolean personalityUpdated,
            int milestone,
            String previousPersonalityCode,
            String personalityCode) {
    }
}
