package com.novelty.mission;

import java.util.HashSet;
import java.util.Objects;
import java.util.OptionalDouble;
import java.util.Set;

public final class MissionExperienceSimilarity {

    private final MissionSemanticSimilarity semanticSimilarity;

    public MissionExperienceSimilarity(MissionSemanticSimilarity semanticSimilarity) {
        this.semanticSimilarity = Objects.requireNonNull(
                semanticSimilarity, "semanticSimilarity is required.");
    }

    public double calculate(Mission left, Mission right) {
        Objects.requireNonNull(left, "left mission is required.");
        Objects.requireNonNull(right, "right mission is required.");

        double metadata = 0.0;
        metadata += same(left.category(), right.category()) * 0.12;
        metadata += same(left.actionType(), right.actionType()) * 0.22;
        metadata += same(left.indoorOutdoor(), right.indoorOutdoor()) * 0.08;
        metadata += levelSimilarity(left.socialLevel(), right.socialLevel(), 2) * 0.08;
        metadata += levelSimilarity(left.activityLevel(), right.activityLevel(), 2) * 0.08;
        metadata += levelSimilarity(left.creativityLevel(), right.creativityLevel(), 2) * 0.10;
        metadata += levelSimilarity(left.unpredictabilityLevel(), right.unpredictabilityLevel(), 2) * 0.07;
        metadata += same(left.durationLevel(), right.durationLevel()) * 0.05;
        metadata += same(left.costLevel(), right.costLevel()) * 0.05;
        metadata += jaccard(left.tags(), right.tags()) * 0.15;

        double lexical = MissionSimilarityPolicy.jaccardBigrams(
                MissionSimilarityPolicy.normalize(left.title() + left.description()),
                MissionSimilarityPolicy.normalize(right.title() + right.description()));
        double fallback = Math.max(metadata, lexical * 0.85);
        OptionalDouble semantic = semanticSimilarity.similarity(left, right);
        return clamp(semantic.isPresent() ? Math.max(fallback, semantic.getAsDouble()) : fallback);
    }

    private double jaccard(Set<String> left, Set<String> right) {
        Set<String> intersection = new HashSet<>(left);
        intersection.retainAll(right);
        Set<String> union = new HashSet<>(left);
        union.addAll(right);
        return union.isEmpty() ? 0.0 : (double) intersection.size() / union.size();
    }

    private double same(Object left, Object right) {
        return Objects.equals(left, right) ? 1.0 : 0.0;
    }

    private double levelSimilarity(int left, int right, int range) {
        return 1.0 - Math.min(range, Math.abs(left - right)) / (double) range;
    }

    private double clamp(double value) {
        return Math.max(0.0, Math.min(1.0, value));
    }
}
