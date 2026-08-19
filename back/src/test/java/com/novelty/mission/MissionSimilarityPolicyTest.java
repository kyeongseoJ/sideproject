package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;

import org.junit.jupiter.api.Test;

class MissionSimilarityPolicyTest {

    private final MissionSimilarityPolicy policy = new MissionSimilarityPolicy();

    @Test
    void rejectsSameNormalizedTitle() {
        GeneratedMission generated = generated("새로운 골목 걷기", "다른 설명");
        Mission existing = mission("새로운  골목 걷기", "기존 설명");

        assertThat(policy.isTooSimilar(generated, List.of(existing))).isTrue();
    }

    @Test
    void rejectsHighlySimilarActionAndAllowsDifferentAction() {
        Mission existing = mission(
                "낯선 음악 한 곡 듣기",
                "평소 듣지 않는 장르의 음악 한 곡을 끝까지 들어 보세요");

        assertThat(policy.isTooSimilar(
                generated("낯선 음악 한 곡 들어보기", "평소 듣지 않는 장르 음악을 끝까지 들어 보세요"),
                List.of(existing))).isTrue();
        assertThat(policy.isTooSimilar(
                generated("공원에서 나뭇잎 모양 기록하기", "서로 다른 나뭇잎 세 개를 관찰해 보세요"),
                List.of(existing))).isFalse();
    }

    private GeneratedMission generated(String title, String description) {
        return new GeneratedMission(
                title, description, MissionCategory.CULTURE, 1, 10, 0, -1, 0, 2);
    }

    private Mission mission(String title, String description) {
        return new Mission(
                1L, title, description, MissionCategory.CULTURE,
                1, 10, 0, -1, 0, 2, true, MissionSourceType.BASE);
    }
}
