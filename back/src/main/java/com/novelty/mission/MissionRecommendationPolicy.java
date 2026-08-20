package com.novelty.mission;

import java.time.Clock;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.Predicate;
import java.util.random.RandomGenerator;

import org.springframework.stereotype.Component;

@Component
public class MissionRecommendationPolicy {

    static final int CANDIDATE_LIMIT = 5;
    static final int RANKED_POOL_LIMIT = 10;
    private static final int COMPLETED_BLOCK_DAYS = 3;
    private static final int SHOWN_BLOCK_DAYS = 2;
    private static final double DISTANCE_WEIGHT = 0.70;
    private static final double CATEGORY_WEIGHT = 0.20;
    private static final double DIFFICULTY_WEIGHT = 0.10;

    private final Clock clock;

    public MissionRecommendationPolicy(Clock serviceClock) {
        this.clock = Objects.requireNonNull(serviceClock, "serviceClock is required.");
    }

    public List<MissionRecommendation> recommend(
            List<Mission> missions,
            UserMissionVector userVector,
            AvailableTime availableTime,
            Map<MissionCategory, Integer> categoryCompletionCounts,
            List<MissionStatusEvent> history,
            RandomGenerator random) {
        validateInputs(
                missions,
                userVector,
                availableTime,
                categoryCompletionCounts,
                history,
                random);

        Set<Long> recentlyCompleted = missionIdsWithinWindow(
                history, MissionStatus.COMPLETED, COMPLETED_BLOCK_DAYS);
        Set<Long> recentlyShown = missionIdsWithinWindow(
                history, MissionStatus.SHOWN, SHOWN_BLOCK_DAYS);
        MissionCategory recentPerformedCategory = mostRecentPerformedCategory(history);

        List<MissionRecommendation> rankedPool = missions.stream()
                .filter(Mission::enabled)
                .filter(mission -> mission.estimatedMinutes() <= availableTime.maximumMinutes())
                .filter(mission -> userVector.completedMissionCount() >= 5
                        || mission.sourceType() == MissionSourceType.BASE)
                .filter(mission -> !recentlyCompleted.contains(mission.id()))
                .filter(mission -> !recentlyShown.contains(mission.id()))
                .map(mission -> score(mission, userVector, categoryCompletionCounts))
                .sorted(Comparator.comparingDouble(MissionRecommendation::recommendationScore)
                        .reversed()
                        .thenComparingLong(recommendation -> recommendation.mission().id()))
                .limit(RANKED_POOL_LIMIT)
                .toList();

        return selectDiverseCandidates(rankedPool, recentPerformedCategory, random);
    }

    /**
     * Legacy single-mission API compatibility. Phase 3 replaces its caller with the full
     * recommendation contract.
     */
    public List<MissionCandidate> filterEligible(
            List<MissionCandidate> candidates,
            List<MissionStatusEvent> history) {
        Objects.requireNonNull(candidates, "candidates are required.");
        Objects.requireNonNull(history, "history is required.");
        Set<Long> recentlyCompleted = missionIdsWithinWindow(
                history, MissionStatus.COMPLETED, COMPLETED_BLOCK_DAYS);
        Set<Long> recentlyShown = missionIdsWithinWindow(
                history, MissionStatus.SHOWN, SHOWN_BLOCK_DAYS);
        return candidates.stream()
                .filter(Objects::nonNull)
                .filter(candidate -> !recentlyCompleted.contains(candidate.missionId()))
                .filter(candidate -> !recentlyShown.contains(candidate.missionId()))
                .toList();
    }

    private MissionRecommendation score(
            Mission mission,
            UserMissionVector userVector,
            Map<MissionCategory, Integer> categoryCompletionCounts) {
        double distance = userVector.distanceFrom(mission);
        int categoryCompletedCount = categoryCompletionCounts.getOrDefault(mission.category(), 0);
        double categoryScore = 1.0 / (1.0 + categoryCompletedCount);
        int preferredDifficulty = userVector.completedMissionCount() < 5 ? 1 : 2;
        double difficultyScore = 1.0 - Math.abs(mission.difficulty() - preferredDifficulty) / 2.0;
        double recommendationScore = clamp(
                distance * DISTANCE_WEIGHT
                        + categoryScore * CATEGORY_WEIGHT
                        + difficultyScore * DIFFICULTY_WEIGHT);
        return new MissionRecommendation(
                mission,
                distance,
                categoryScore,
                difficultyScore,
                recommendationScore);
    }

    private List<MissionRecommendation> selectDiverseCandidates(
            List<MissionRecommendation> rankedPool,
            MissionCategory recentPerformedCategory,
            RandomGenerator random) {
        List<MissionRecommendation> remaining = new ArrayList<>(rankedPool);
        List<MissionRecommendation> selected = new ArrayList<>();
        Set<MissionCategory> selectedCategories = new HashSet<>();

        while (!remaining.isEmpty() && selected.size() < CANDIDATE_LIMIT) {
            List<MissionRecommendation> preferred = matching(
                    remaining,
                    recommendation -> !selectedCategories.contains(recommendation.mission().category())
                            && recommendation.mission().category() != recentPerformedCategory);
            if (preferred.isEmpty()) {
                preferred = matching(
                        remaining,
                        recommendation -> !selectedCategories.contains(recommendation.mission().category()));
            }
            if (preferred.isEmpty()) {
                preferred = matching(
                        remaining,
                        recommendation -> recommendation.mission().category() != recentPerformedCategory);
            }
            if (preferred.isEmpty()) {
                preferred = remaining;
            }

            MissionRecommendation chosen = weightedChoice(preferred, random);
            selected.add(chosen);
            selectedCategories.add(chosen.mission().category());
            remaining.remove(chosen);
        }
        return List.copyOf(selected);
    }

    private List<MissionRecommendation> matching(
            List<MissionRecommendation> candidates,
            Predicate<MissionRecommendation> predicate) {
        return candidates.stream().filter(predicate).toList();
    }

    private MissionRecommendation weightedChoice(
            List<MissionRecommendation> candidates,
            RandomGenerator random) {
        double totalWeight = candidates.stream()
                .mapToDouble(MissionRecommendation::recommendationScore)
                .sum();
        if (totalWeight <= 0.0) {
            return candidates.get(random.nextInt(candidates.size()));
        }

        double target = random.nextDouble(totalWeight);
        double cumulative = 0.0;
        for (MissionRecommendation candidate : candidates) {
            cumulative += candidate.recommendationScore();
            if (target < cumulative) {
                return candidate;
            }
        }
        return candidates.getLast();
    }

    private Set<Long> missionIdsWithinWindow(
            List<MissionStatusEvent> history,
            MissionStatus status,
            int windowDays) {
        LocalDate serviceDate = LocalDate.now(clock);
        LocalDate firstBlockedDate = serviceDate.minusDays(windowDays - 1L);
        Set<Long> missionIds = new HashSet<>();

        for (MissionStatusEvent event : history) {
            LocalDate eventDate = event.occurredAt()
                    .atZoneSameInstant(clock.getZone())
                    .toLocalDate();
            if (event.status() == status
                    && !eventDate.isBefore(firstBlockedDate)
                    && !eventDate.isAfter(serviceDate)) {
                missionIds.add(event.missionId());
            }
        }
        return missionIds;
    }

    private MissionCategory mostRecentPerformedCategory(List<MissionStatusEvent> history) {
        LocalDate serviceDate = LocalDate.now(clock);
        return history.stream()
                .filter(event -> event.status() == MissionStatus.SELECTED
                        || event.status() == MissionStatus.COMPLETED)
                .filter(event -> !event.occurredAt()
                        .atZoneSameInstant(clock.getZone())
                        .toLocalDate()
                        .isAfter(serviceDate))
                .max(Comparator.comparing(MissionStatusEvent::occurredAt))
                .map(MissionStatusEvent::category)
                .map(MissionCategory::valueOf)
                .orElse(null);
    }

    private void validateInputs(
            List<Mission> missions,
            UserMissionVector userVector,
            AvailableTime availableTime,
            Map<MissionCategory, Integer> categoryCompletionCounts,
            List<MissionStatusEvent> history,
            RandomGenerator random) {
        Objects.requireNonNull(missions, "missions are required.");
        Objects.requireNonNull(userVector, "userVector is required.");
        Objects.requireNonNull(availableTime, "availableTime is required.");
        Objects.requireNonNull(categoryCompletionCounts, "categoryCompletionCounts are required.");
        Objects.requireNonNull(history, "history is required.");
        Objects.requireNonNull(random, "random is required.");

        Set<Long> missionIds = new HashSet<>();
        for (Mission mission : missions) {
            if (mission == null) {
                throw new IllegalArgumentException("missions cannot contain null.");
            }
            if (!missionIds.add(mission.id())) {
                throw new IllegalArgumentException("duplicate mission id: " + mission.id());
            }
        }
        for (Map.Entry<MissionCategory, Integer> entry : categoryCompletionCounts.entrySet()) {
            if (entry.getKey() == null || entry.getValue() == null || entry.getValue() < 0) {
                throw new IllegalArgumentException("category completion counts must be non-negative.");
            }
        }
        for (MissionStatusEvent event : history) {
            if (event == null
                    || event.missionId() <= 0
                    || event.status() == null
                    || event.category() == null
                    || event.occurredAt() == null) {
                throw new IllegalArgumentException("mission history is invalid.");
            }
            try {
                MissionCategory.valueOf(event.category());
            } catch (IllegalArgumentException exception) {
                throw new IllegalArgumentException("mission history category is invalid.", exception);
            }
        }
    }

    private double clamp(double value) {
        return Math.max(0.0, Math.min(1.0, value));
    }
}
