package com.novelty.personality;

import java.util.Arrays;

public enum PersonalityType {
    QUIET_FOCUSER(
            IndoorOutdoor.INDOOR,
            SocialLevel.LOW,
            "고요한 몰입가",
            "익숙하고 조용한 공간에서 혼자 집중할 때 편안해요."),
    COZY_EXPLORER(
            IndoorOutdoor.INDOOR,
            SocialLevel.MEDIUM,
            "아늑한 탐색가",
            "편안한 공간을 중심으로 가끔 새로운 연결을 즐겨요."),
    WARM_HOST(
            IndoorOutdoor.INDOOR,
            SocialLevel.HIGH,
            "다정한 아지트지기",
            "편안한 공간에서 사람들과 온기를 나누는 것을 좋아해요."),
    FLEXIBLE_INDEPENDENT(
            IndoorOutdoor.MIXED,
            SocialLevel.LOW,
            "유연한 독립가",
            "장소에 얽매이지 않고 혼자만의 리듬을 지키는 편이에요."),
    BALANCED_COORDINATOR(
            IndoorOutdoor.MIXED,
            SocialLevel.MEDIUM,
            "균형 조율가",
            "혼자와 함께, 실내와 실외 사이를 상황에 맞게 조율해요."),
    OPEN_CONNECTOR(
            IndoorOutdoor.MIXED,
            SocialLevel.HIGH,
            "열린 연결가",
            "다양한 장소에서 사람과 자연스럽게 어울리는 편이에요."),
    SOLO_EXPLORER(
            IndoorOutdoor.OUTDOOR,
            SocialLevel.LOW,
            "독립 탐험가",
            "바깥에서 혼자 발견하고 경험하는 시간을 좋아해요."),
    FREE_PIONEER(
            IndoorOutdoor.OUTDOOR,
            SocialLevel.MEDIUM,
            "자유로운 개척자",
            "바깥 활동을 즐기며 필요할 때 사람과 연결돼요."),
    ACTIVE_CONNECTOR(
            IndoorOutdoor.OUTDOOR,
            SocialLevel.HIGH,
            "활기찬 연결가",
            "바깥에서 사람들과 함께 움직일 때 활력을 느껴요.");

    private final IndoorOutdoor indoorOutdoor;
    private final SocialLevel socialLevel;
    private final String displayName;
    private final String summary;

    PersonalityType(
            IndoorOutdoor indoorOutdoor,
            SocialLevel socialLevel,
            String displayName,
            String summary) {
        this.indoorOutdoor = indoorOutdoor;
        this.socialLevel = socialLevel;
        this.displayName = displayName;
        this.summary = summary;
    }

    public IndoorOutdoor indoorOutdoor() {
        return indoorOutdoor;
    }

    public SocialLevel socialLevel() {
        return socialLevel;
    }

    public String displayName() {
        return displayName;
    }

    public String summary() {
        return summary;
    }

    public static PersonalityType from(IndoorOutdoor indoorOutdoor, SocialLevel socialLevel) {
        return Arrays.stream(values())
                .filter(type -> type.indoorOutdoor == indoorOutdoor && type.socialLevel == socialLevel)
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("지원하지 않는 성향 축 조합입니다."));
    }
}
