package com.novelty.mission;

import static com.novelty.mission.MissionRecommendationConfig.CANDIDATE_LIMIT;
import static com.novelty.mission.MissionRecommendationConfig.CATEGORY_EXPLORATION_WEIGHT;
import static com.novelty.mission.MissionRecommendationConfig.COMPLETED_HARD_BLOCK_MAX_AGE_DAYS;
import static com.novelty.mission.MissionRecommendationConfig.CONTEXT_FIT_WEIGHT;
import static com.novelty.mission.MissionRecommendationConfig.EXPLORATION_WEIGHT;
import static com.novelty.mission.MissionRecommendationConfig.FINAL_DIVERSITY_PENALTY;
import static com.novelty.mission.MissionRecommendationConfig.FINAL_HARD_SIMILARITY;
import static com.novelty.mission.MissionRecommendationConfig.NOVELTY_WEIGHT;
import static com.novelty.mission.MissionRecommendationConfig.PERSONALITY_WEIGHT;
import static com.novelty.mission.MissionRecommendationConfig.RANKED_POOL_LIMIT;
import static com.novelty.mission.MissionRecommendationConfig.RECENT_COMPLETED_LIMIT;
import static com.novelty.mission.MissionRecommendationConfig.RECENT_DIVERSITY_WEIGHT;
import static com.novelty.mission.MissionRecommendationConfig.RECENT_EXPERIENCE_DAYS;
import static com.novelty.mission.MissionRecommendationConfig.RECENT_HARD_SIMILARITY;
import static com.novelty.mission.MissionRecommendationConfig.RECENT_SIMILARITY_PENALTY;
import static com.novelty.mission.MissionRecommendationConfig.RECENCY_DECAY;
import static com.novelty.mission.MissionRecommendationConfig.REEXPOSURE_BLOCK_DAYS;
import static com.novelty.mission.MissionRecommendationConfig.REJECTION_PENALTY;
import static com.novelty.mission.MissionRecommendationConfig.REPEATED_PATTERN_PENALTY;
import static com.novelty.mission.MissionRecommendationConfig.REPEAT_HIGH_MAX_AGE_DAYS;
import static com.novelty.mission.MissionRecommendationConfig.REPEAT_HIGH_PENALTY;
import static com.novelty.mission.MissionRecommendationConfig.REPEAT_LOW_MAX_AGE_DAYS;
import static com.novelty.mission.MissionRecommendationConfig.REPEAT_LOW_PENALTY;
import static com.novelty.mission.MissionRecommendationConfig.REPEAT_VERY_HIGH_MAX_AGE_DAYS;
import static com.novelty.mission.MissionRecommendationConfig.REPEAT_VERY_HIGH_PENALTY;

import java.time.Clock;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.random.RandomGenerator;

import org.springframework.stereotype.Component;

import com.novelty.personality.Interest;
import com.novelty.personality.ExecutionStyle;

@Component
public class MissionRecommendationPolicy {

    private final Clock clock;
    private final MissionExperienceSimilarity experienceSimilarity;

    public MissionRecommendationPolicy(
            Clock serviceClock,
            MissionSemanticSimilarity semanticSimilarity) {
        this.clock = Objects.requireNonNull(serviceClock, "serviceClock is required.");
        this.experienceSimilarity = new MissionExperienceSimilarity(semanticSimilarity);
    }

    public List<MissionRecommendation> recommend(
            List<Mission> missions,
            UserMissionVector userVector,
            Map<MissionCategory, Integer> categoryCompletionCounts,
            List<MissionStatusEvent> history,
            RandomGenerator random) {
        return recommend(missions, userVector, Set.of(), null, categoryCompletionCounts, history, random);
    }

    public List<MissionRecommendation> recommend(
            List<Mission> missions,
            UserMissionVector userVector,
            Set<Interest> userInterests,
            Map<MissionCategory, Integer> categoryCompletionCounts,
            List<MissionStatusEvent> history,
            RandomGenerator random) {
        return recommend(
                missions, userVector, userInterests, null,
                categoryCompletionCounts, history, random);
    }

    public List<MissionRecommendation> recommend(
            List<Mission> missions,
            UserMissionVector userVector,
            Set<Interest> userInterests,
            ExecutionStyle executionStyle,
            Map<MissionCategory, Integer> categoryCompletionCounts,
            List<MissionStatusEvent> history,
            RandomGenerator random) {
        validateInputs(missions, userVector, categoryCompletionCounts, history, random);
        Objects.requireNonNull(userInterests, "userInterests are required.");

        Set<Long> recentlyCompletedIds = missionIdsWithinMaximumAge(
                history, MissionStatus.COMPLETED, COMPLETED_HARD_BLOCK_MAX_AGE_DAYS);
        Set<Long> recentlyShownIds = missionIdsWithinWindow(
                history, MissionStatus.SHOWN, REEXPOSURE_BLOCK_DAYS);
        List<WeightedExperience> recentCompleted = recentCompleted(history);
        MissionCategory latestPerformedCategory = mostRecentPerformedCategory(history);

        List<MissionRecommendation> rankedPool = missions.stream()
                .filter(Mission::enabled)
                .filter(mission -> !userInterests.contains(Interest.valueOf(mission.category().name())))
                .filter(mission -> !recentlyCompletedIds.contains(mission.id()))
                .filter(mission -> !recentlyShownIds.contains(mission.id()))
                .filter(mission -> !isNearDuplicateOfRecentExperience(mission, recentCompleted))
                .map(mission -> score(
                        mission,
                        userVector,
                        executionStyle,
                        categoryCompletionCounts,
                        history,
                        recentCompleted,
                        latestPerformedCategory))
                .sorted(Comparator.comparingDouble(MissionRecommendation::recommendationScore)
                        .reversed()
                        .thenComparingLong(recommendation -> recommendation.mission().id()))
                .limit(RANKED_POOL_LIMIT)
                .toList();

        return selectDiverseCandidates(rankedPool, random);
    }

    /** Compatibility for the removed single-mission runtime path and its regression tests. */
    public List<MissionCandidate> filterEligible(
            List<MissionCandidate> candidates,
            List<MissionStatusEvent> history) {
        Objects.requireNonNull(candidates, "candidates are required.");
        Objects.requireNonNull(history, "history is required.");
        Set<Long> recentlyCompleted = missionIdsWithinMaximumAge(
                history, MissionStatus.COMPLETED, COMPLETED_HARD_BLOCK_MAX_AGE_DAYS);
        Set<Long> recentlyShown = missionIdsWithinWindow(
                history, MissionStatus.SHOWN, REEXPOSURE_BLOCK_DAYS);
        return candidates.stream()
                .filter(Objects::nonNull)
                .filter(candidate -> !recentlyCompleted.contains(candidate.missionId()))
                .filter(candidate -> !recentlyShown.contains(candidate.missionId()))
                .toList();
    }

    private MissionRecommendation score(
            Mission mission,
            UserMissionVector userVector,
            ExecutionStyle executionStyle,
            Map<MissionCategory, Integer> categoryCompletionCounts,
            List<MissionStatusEvent> history,
            List<WeightedExperience> recentCompleted,
            MissionCategory latestPerformedCategory) {
        double personalityDistance = userVector.distanceFrom(mission);
        double noveltyScore = mission.noveltyLevel() / 2.0;
        int categoryCompletedCount = categoryCompletionCounts.getOrDefault(mission.category(), 0);
        double categoryExplorationScore = 1.0 / (1.0 + categoryCompletedCount);
        double difficultyFitScore = difficultyFit(mission, userVector);
        double executionStyleFitScore = executionStyleFit(mission, executionStyle);
        double contextFitScore = (difficultyFitScore + executionStyleFitScore) / 2.0;

        double recentSimilarity = maximumRecentSimilarity(mission, recentCompleted);
        double repeatedPattern = maximumRepeatedPattern(mission, recentCompleted);
        double recentDiversityScore = 1.0 - recentSimilarity;
        double explorationBonus = 1.0 - repeatedPattern;
        double similarityPenalty = recentSimilarity * RECENT_SIMILARITY_PENALTY;
        double repetitionPenalty = repeatedPattern * REPEATED_PATTERN_PENALTY;
        if (latestPerformedCategory == mission.category()) {
            repetitionPenalty = Math.min(1.0, repetitionPenalty + REPEATED_PATTERN_PENALTY);
        }
        double rejectionPenalty = rejectedPatternScore(mission, history) * REJECTION_PENALTY;
        double longTermRepeatPenalty = longTermRepeatPenalty(mission, history);

        double positiveScore = personalityDistance * PERSONALITY_WEIGHT
                + noveltyScore * NOVELTY_WEIGHT
                + categoryExplorationScore * CATEGORY_EXPLORATION_WEIGHT
                + recentDiversityScore * RECENT_DIVERSITY_WEIGHT
                + explorationBonus * EXPLORATION_WEIGHT
                + contextFitScore * CONTEXT_FIT_WEIGHT;
        double recommendationScore = clamp(
                positiveScore - similarityPenalty - repetitionPenalty
                        - rejectionPenalty - longTermRepeatPenalty);

        return new MissionRecommendation(
                mission,
                personalityDistance,
                categoryExplorationScore,
                difficultyFitScore,
                noveltyScore,
                recentDiversityScore,
                explorationBonus,
                contextFitScore,
                similarityPenalty,
                repetitionPenalty,
                rejectionPenalty,
                longTermRepeatPenalty,
                recommendationScore);
    }

    private List<MissionRecommendation> selectDiverseCandidates(
            List<MissionRecommendation> rankedPool,
            RandomGenerator random) {
        if (rankedPool.isEmpty()) {
            return List.of();
        }

        List<MissionRecommendation> remaining = new ArrayList<>(rankedPool);
        List<MissionRecommendation> selected = new ArrayList<>();
        MissionRecommendation first = weightedChoice(remaining, random);
        selected.add(first);
        remaining.remove(first);

        while (!remaining.isEmpty() && selected.size() < CANDIDATE_LIMIT) {
            List<MissionRecommendation> sufficientlyDifferent = remaining.stream()
                    .filter(candidate -> maximumSelectedSimilarity(candidate, selected)
                            < FINAL_HARD_SIMILARITY)
                    .toList();
            List<MissionRecommendation> pool = sufficientlyDifferent.isEmpty()
                    ? remaining
                    : sufficientlyDifferent;
            Set<Integer> selectedDurationLevels = selected.stream()
                    .map(recommendation -> recommendation.mission().durationLevel())
                    .collect(java.util.stream.Collectors.toSet());
            List<MissionRecommendation> unusedDurationPool = pool.stream()
                    .filter(candidate -> !selectedDurationLevels.contains(
                            candidate.mission().durationLevel()))
                    .toList();
            if (!unusedDurationPool.isEmpty()) {
                pool = unusedDurationPool;
            }
            MissionRecommendation chosen = pool.stream()
                    .max(Comparator.<MissionRecommendation>comparingDouble(
                                    candidate -> diversityAdjustedScore(candidate, selected))
                            .thenComparingLong(candidate -> -candidate.mission().id()))
                    .orElseThrow();
            selected.add(chosen);
            remaining.remove(chosen);
        }
        return List.copyOf(selected);
    }

    private double diversityAdjustedScore(
            MissionRecommendation candidate,
            List<MissionRecommendation> selected) {
        return candidate.recommendationScore()
                - maximumSelectedSimilarity(candidate, selected) * FINAL_DIVERSITY_PENALTY;
    }

    private double maximumSelectedSimilarity(
            MissionRecommendation candidate,
            List<MissionRecommendation> selected) {
        return selected.stream()
                .mapToDouble(existing -> experienceSimilarity.calculate(
                        candidate.mission(), existing.mission()))
                .max()
                .orElse(0.0);
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

    private List<WeightedExperience> recentCompleted(List<MissionStatusEvent> history) {
        LocalDate serviceDate = LocalDate.now(clock);
        LocalDate firstDate = serviceDate.minusDays(RECENT_EXPERIENCE_DAYS - 1L);
        return history.stream()
                .filter(event -> event.status() == MissionStatus.COMPLETED)
                .filter(event -> event.mission() != null)
                .filter(event -> isWithin(event, firstDate, serviceDate))
                .sorted(Comparator.comparing(MissionStatusEvent::occurredAt).reversed())
                .limit(RECENT_COMPLETED_LIMIT)
                .map(event -> new WeightedExperience(
                        event.mission(), recencyWeight(event, serviceDate)))
                .toList();
    }

    private boolean isNearDuplicateOfRecentExperience(
            Mission candidate,
            List<WeightedExperience> recentCompleted) {
        return recentCompleted.stream().anyMatch(experience ->
                candidate.id() != experience.mission().id()
                        && experienceSimilarity.calculate(candidate, experience.mission())
                        >= RECENT_HARD_SIMILARITY);
    }

    private double longTermRepeatPenalty(
            Mission candidate,
            List<MissionStatusEvent> history) {
        LocalDate serviceDate = LocalDate.now(clock);
        long ageDays = history.stream()
                .filter(event -> event.status() == MissionStatus.COMPLETED)
                .filter(event -> event.missionId() == candidate.id())
                .map(this::eventDate)
                .filter(date -> !date.isAfter(serviceDate))
                .mapToLong(date -> ChronoUnit.DAYS.between(date, serviceDate))
                .min()
                .orElse(Long.MAX_VALUE);
        if (ageDays <= COMPLETED_HARD_BLOCK_MAX_AGE_DAYS) {
            return 0.0;
        }
        if (ageDays <= REPEAT_VERY_HIGH_MAX_AGE_DAYS) {
            return REPEAT_VERY_HIGH_PENALTY;
        }
        if (ageDays <= REPEAT_HIGH_MAX_AGE_DAYS) {
            return REPEAT_HIGH_PENALTY;
        }
        if (ageDays <= REPEAT_LOW_MAX_AGE_DAYS) {
            return REPEAT_LOW_PENALTY;
        }
        return 0.0;
    }

    private double maximumRecentSimilarity(
            Mission candidate,
            List<WeightedExperience> recentCompleted) {
        return recentCompleted.stream()
                .filter(experience -> candidate.id() != experience.mission().id())
                .mapToDouble(experience -> experienceSimilarity.calculate(
                        candidate, experience.mission()) * experience.recencyWeight())
                .max()
                .orElse(0.0);
    }

    private double maximumRepeatedPattern(
            Mission candidate,
            List<WeightedExperience> recentCompleted) {
        return recentCompleted.stream()
                .filter(experience -> candidate.id() != experience.mission().id())
                .mapToDouble(experience -> patternOverlap(candidate, experience.mission())
                        * experience.recencyWeight())
                .max()
                .orElse(0.0);
    }

    private double patternOverlap(Mission left, Mission right) {
        double overlap = 0.0;
        overlap += left.category() == right.category() ? 0.20 : 0.0;
        overlap += left.actionType() == right.actionType() ? 0.30 : 0.0;
        overlap += left.indoorOutdoor() == right.indoorOutdoor() ? 0.10 : 0.0;
        overlap += left.socialLevel() == right.socialLevel() ? 0.10 : 0.0;
        overlap += left.activityLevel() == right.activityLevel() ? 0.10 : 0.0;
        overlap += left.creativityLevel() == right.creativityLevel() ? 0.05 : 0.0;
        overlap += tagJaccard(left.tags(), right.tags()) * 0.15;
        return clamp(overlap);
    }

    private double rejectedPatternScore(Mission candidate, List<MissionStatusEvent> history) {
        Map<Long, List<MissionStatusEvent>> byUserMission = new HashMap<>();
        for (MissionStatusEvent event : history) {
            if (event.userMissionId() != null) {
                byUserMission.computeIfAbsent(event.userMissionId(), ignored -> new ArrayList<>())
                        .add(event);
            }
        }

        double accumulated = 0.0;
        LocalDate serviceDate = LocalDate.now(clock);
        LocalDate firstDate = serviceDate.minusDays(13);
        for (List<MissionStatusEvent> events : byUserMission.values()) {
            boolean wasShown = events.stream().anyMatch(event -> event.status() == MissionStatus.SHOWN);
            boolean wasSelected = events.stream().anyMatch(event -> event.status() == MissionStatus.SELECTED);
            boolean wasCompleted = events.stream().anyMatch(event -> event.status() == MissionStatus.COMPLETED);
            boolean wasCancelled = events.stream().anyMatch(event -> event.status() == MissionStatus.CANCELLED);
            MissionStatusEvent shown = events.stream()
                    .filter(event -> event.status() == MissionStatus.SHOWN)
                    .filter(event -> event.mission() != null)
                    .filter(event -> isWithin(event, firstDate, serviceDate))
                    .max(Comparator.comparing(MissionStatusEvent::occurredAt))
                    .orElse(null);
            boolean skipped = wasShown && !wasSelected && !wasCompleted;
            boolean rejected = wasCancelled && !wasCompleted;
            if ((skipped || rejected) && shown != null) {
                double comfortFactor = (candidate.comfortZoneDistance() + 1) / 3.0;
                accumulated += patternOverlap(candidate, shown.mission())
                        * recencyWeight(shown, serviceDate)
                        * comfortFactor
                        * 0.5;
            }
        }
        return clamp(accumulated);
    }

    private double difficultyFit(Mission mission, UserMissionVector userVector) {
        int preferredDifficulty = userVector.completedMissionCount() < 5 ? 1 : 2;
        return 1.0 - Math.abs(mission.difficulty() - preferredDifficulty) / 2.0;
    }

    private double executionStyleFit(Mission mission, ExecutionStyle executionStyle) {
        if (executionStyle == null) {
            return 0.5;
        }
        return switch (executionStyle) {
            case PLANNED -> switch (mission.actionType()) {
                case ORGANIZE, PRACTICE, CREATE -> 1.0;
                default -> 0.5;
            };
            case FLEXIBLE -> switch (mission.actionType()) {
                case OBSERVE, TASTE, LISTEN, ASK -> 1.0;
                default -> 0.5;
            };
            case SPONTANEOUS -> switch (mission.actionType()) {
                case EXPLORE, CONNECT, EXERCISE -> 1.0;
                default -> 0.5;
            };
        };
    }

    private double recencyWeight(MissionStatusEvent event, LocalDate serviceDate) {
        long days = ChronoUnit.DAYS.between(eventDate(event), serviceDate);
        return Math.pow(RECENCY_DECAY, Math.max(0, days));
    }

    private Set<Long> missionIdsWithinWindow(
            List<MissionStatusEvent> history,
            MissionStatus status,
            int windowDays) {
        LocalDate serviceDate = LocalDate.now(clock);
        LocalDate firstBlockedDate = serviceDate.minusDays(windowDays - 1L);
        Set<Long> missionIds = new HashSet<>();
        for (MissionStatusEvent event : history) {
            if (event.status() == status && isWithin(event, firstBlockedDate, serviceDate)) {
                missionIds.add(event.missionId());
            }
        }
        return missionIds;
    }

    private Set<Long> missionIdsWithinMaximumAge(
            List<MissionStatusEvent> history,
            MissionStatus status,
            int maximumAgeDays) {
        LocalDate serviceDate = LocalDate.now(clock);
        Set<Long> missionIds = new HashSet<>();
        for (MissionStatusEvent event : history) {
            long ageDays = ChronoUnit.DAYS.between(eventDate(event), serviceDate);
            if (event.status() == status && ageDays >= 0 && ageDays <= maximumAgeDays) {
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
                .filter(event -> !eventDate(event).isAfter(serviceDate))
                .max(Comparator.comparing(MissionStatusEvent::occurredAt))
                .map(MissionStatusEvent::category)
                .map(MissionCategory::valueOf)
                .orElse(null);
    }

    private boolean isWithin(
            MissionStatusEvent event,
            LocalDate firstDate,
            LocalDate lastDate) {
        LocalDate date = eventDate(event);
        return !date.isBefore(firstDate) && !date.isAfter(lastDate);
    }

    private LocalDate eventDate(MissionStatusEvent event) {
        return event.occurredAt().atZoneSameInstant(clock.getZone()).toLocalDate();
    }

    private double tagJaccard(Set<String> left, Set<String> right) {
        Set<String> intersection = new HashSet<>(left);
        intersection.retainAll(right);
        Set<String> union = new HashSet<>(left);
        union.addAll(right);
        return union.isEmpty() ? 0.0 : (double) intersection.size() / union.size();
    }

    private void validateInputs(
            List<Mission> missions,
            UserMissionVector userVector,
            Map<MissionCategory, Integer> categoryCompletionCounts,
            List<MissionStatusEvent> history,
            RandomGenerator random) {
        Objects.requireNonNull(missions, "missions are required.");
        Objects.requireNonNull(userVector, "userVector is required.");
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
            if (event.mission() != null
                    && (event.mission().id() != event.missionId()
                            || !event.mission().category().name().equals(event.category()))) {
                throw new IllegalArgumentException("mission history metadata is inconsistent.");
            }
        }
    }

    private double clamp(double value) {
        return Math.max(0.0, Math.min(1.0, value));
    }

    private record WeightedExperience(Mission mission, double recencyWeight) {
    }
}
