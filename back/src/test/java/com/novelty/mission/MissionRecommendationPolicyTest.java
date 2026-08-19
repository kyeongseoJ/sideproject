package com.novelty.mission;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class MissionRecommendationPolicyTest {

    private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");
    private static final Instant NOW = Instant.parse("2026-08-20T03:00:00Z");

    private MissionRecommendationPolicy policy;

    @BeforeEach
    void setUp() {
        policy = new MissionRecommendationPolicy(Clock.fixed(NOW, SEOUL));
    }

    @Test
    void blocksCompletedMissionForThreeServiceDates() {
        List<MissionCandidate> candidates = List.of(
                candidate(1, "MOVEMENT"),
                candidate(2, "FOOD"),
                candidate(3, "CULTURE"));
        List<MissionStatusEvent> history = List.of(
                event(1, "MOVEMENT", MissionStatus.COMPLETED, "2026-08-18T10:00:00+09:00"),
                event(2, "FOOD", MissionStatus.COMPLETED, "2026-08-17T23:59:00+09:00"));

        assertEquals(List.of(candidate(2, "FOOD"), candidate(3, "CULTURE")),
                policy.filterEligible(candidates, history));
    }

    @Test
    void blocksShownMissionForTwoServiceDates() {
        List<MissionCandidate> candidates = List.of(
                candidate(1, "MOVEMENT"),
                candidate(2, "FOOD"),
                candidate(3, "CULTURE"));
        List<MissionStatusEvent> history = List.of(
                event(1, "MOVEMENT", MissionStatus.SHOWN, "2026-08-19T09:00:00+09:00"),
                event(2, "FOOD", MissionStatus.SHOWN, "2026-08-18T23:59:00+09:00"));

        assertEquals(List.of(candidate(2, "FOOD"), candidate(3, "CULTURE")),
                policy.filterEligible(candidates, history));
    }

    @Test
    void preventsTheMostRecentlyShownCategoryFromRepeating() {
        List<MissionCandidate> candidates = List.of(
                candidate(1, "MOVEMENT"),
                candidate(2, "FOOD"),
                candidate(3, "MOVEMENT"));
        List<MissionStatusEvent> history = List.of(
                event(90, "FOOD", MissionStatus.SHOWN, "2026-08-15T09:00:00+09:00"),
                event(91, "MOVEMENT", MissionStatus.SHOWN, "2026-08-18T09:00:00+09:00"));

        assertEquals(List.of(candidate(2, "FOOD")), policy.filterEligible(candidates, history));
    }

    @Test
    void usesAsiaSeoulDateAtUtcBoundary() {
        List<MissionCandidate> candidates = List.of(candidate(1, "MOVEMENT"));
        List<MissionStatusEvent> history = List.of(new MissionStatusEvent(
                1,
                "FOOD",
                MissionStatus.SHOWN,
                OffsetDateTime.ofInstant(
                        Instant.parse("2026-08-18T15:30:00Z"),
                        ZoneOffset.UTC)));

        assertEquals(List.of(), policy.filterEligible(candidates, history));
    }

    @Test
    void selectedAndCancelledEventsDoNotCreateRecommendationWindows() {
        List<MissionCandidate> candidates = List.of(candidate(1, "MOVEMENT"));
        List<MissionStatusEvent> history = List.of(
                event(1, "FOOD", MissionStatus.SELECTED, "2026-08-20T09:00:00+09:00"),
                event(1, "FOOD", MissionStatus.CANCELLED, "2026-08-20T10:00:00+09:00"));

        assertEquals(candidates, policy.filterEligible(candidates, history));
    }

    private MissionCandidate candidate(long id, String category) {
        return new MissionCandidate(id, category);
    }

    private MissionStatusEvent event(
            long missionId,
            String category,
            MissionStatus status,
            String occurredAt) {
        return new MissionStatusEvent(
                missionId,
                category,
                status,
                OffsetDateTime.parse(occurredAt));
    }
}
