package com.novelty.mission;

public record MissionPersonalityChangeResponse(
        int previousIndoorOutdoor,
        int currentIndoorOutdoor,
        int previousSocialLevel,
        int currentSocialLevel,
        int previousActivityLevel,
        int currentActivityLevel,
        int previousNoveltyLevel,
        int currentNoveltyLevel,
        String previousPersonalityCode,
        String currentPersonalityCode) {

    static MissionPersonalityChangeResponse from(MissionProfileUpdater.CompletionUpdate update) {
        return new MissionPersonalityChangeResponse(
                update.previousVector().indoorOutdoor(),
                update.vector().indoorOutdoor(),
                update.previousVector().socialLevel(),
                update.vector().socialLevel(),
                update.previousVector().activityLevel(),
                update.vector().activityLevel(),
                update.previousVector().noveltyLevel(),
                update.vector().noveltyLevel(),
                update.previousPersonalityCode(),
                update.personalityCode());
    }
}
