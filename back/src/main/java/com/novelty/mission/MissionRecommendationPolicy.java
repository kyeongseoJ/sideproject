package com.novelty.mission;

import java.time.Clock;
import java.time.LocalDate;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.springframework.stereotype.Component;

@Component
public class MissionRecommendationPolicy {

    private static final int COMPLETED_BLOCK_DAYS = 3;
    private static final int SHOWN_BLOCK_DAYS = 2;

    private final Clock clock;

    public MissionRecommendationPolicy(Clock serviceClock) {
        this.clock = serviceClock;
    }

    public List<MissionCandidate> filterEligible(
            List<MissionCandidate> candidates,
            List<MissionStatusEvent> history) {
        LocalDate serviceDate = LocalDate.now(clock);
        Set<Long> recentlyCompleted = missionIdsWithinWindow(
                history,
                MissionStatus.COMPLETED,
                serviceDate,
                COMPLETED_BLOCK_DAYS);
        Set<Long> recentlyShown = missionIdsWithinWindow(
                history,
                MissionStatus.SHOWN,
                serviceDate,
                SHOWN_BLOCK_DAYS);
        String previousShownCategory = history.stream()
                .filter(event -> event.status() == MissionStatus.SHOWN)
                .max(Comparator.comparing(MissionStatusEvent::occurredAt))
                .map(MissionStatusEvent::category)
                .orElse(null);

        return candidates.stream()
                .filter(candidate -> !recentlyCompleted.contains(candidate.missionId()))
                .filter(candidate -> !recentlyShown.contains(candidate.missionId()))
                .filter(candidate -> previousShownCategory == null
                        || !previousShownCategory.equals(candidate.category()))
                .toList();
    }

    private Set<Long> missionIdsWithinWindow(
            List<MissionStatusEvent> history,
            MissionStatus status,
            LocalDate serviceDate,
            int windowDays) {
        LocalDate firstBlockedDate = serviceDate.minusDays(windowDays - 1L);
        Set<Long> missionIds = new HashSet<>();

        for (MissionStatusEvent event : history) {
            LocalDate eventDate = event.occurredAt().atZoneSameInstant(clock.getZone()).toLocalDate();
            if (event.status() == status && !eventDate.isBefore(firstBlockedDate)) {
                missionIds.add(event.missionId());
            }
        }
        return missionIds;
    }
}
