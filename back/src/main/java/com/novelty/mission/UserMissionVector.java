package com.novelty.mission;

public record UserMissionVector(
        int indoorOutdoor,
        int socialLevel,
        int activityLevel,
        int noveltyLevel,
        int completedMissionCount) {

    public UserMissionVector {
        requireRange("indoorOutdoor", indoorOutdoor, -1, 1);
        requireRange("socialLevel", socialLevel, -1, 1);
        requireRange("activityLevel", activityLevel, 0, 2);
        requireRange("noveltyLevel", noveltyLevel, 0, 2);
        requireRange("completedMissionCount", completedMissionCount, 0, Integer.MAX_VALUE);
    }

    public double distanceFrom(Mission mission) {
        return distanceFrom(
                mission.indoorOutdoor(),
                mission.socialLevel(),
                mission.activityLevel(),
                mission.noveltyLevel());
    }

    public double distanceFrom(GeneratedMission mission) {
        return distanceFrom(
                mission.indoorOutdoor(),
                mission.socialLevel(),
                mission.activityLevel(),
                mission.noveltyLevel());
    }

    private double distanceFrom(
            int missionIndoorOutdoor,
            int missionSocialLevel,
            int missionActivityLevel,
            int missionNoveltyLevel) {
        double indoorOutdoorDistance = (indoorOutdoor - missionIndoorOutdoor) / 2.0;
        double socialDistance = (socialLevel - missionSocialLevel) / 2.0;
        double activityDistance = (activityLevel - missionActivityLevel) / 2.0;
        double noveltyDistance = (noveltyLevel - missionNoveltyLevel) / 2.0;
        return Math.sqrt((square(indoorOutdoorDistance)
                + square(socialDistance)
                + square(activityDistance)
                + square(noveltyDistance)) / 4.0);
    }

    private static double square(double value) {
        return value * value;
    }

    private static void requireRange(String name, int value, int minimum, int maximum) {
        if (value < minimum || value > maximum) {
            throw new IllegalArgumentException(name + " is outside its allowed range.");
        }
    }
}
