package com.novelty.mission;

import java.text.Normalizer;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

import org.springframework.stereotype.Component;

@Component
public class MissionSimilarityPolicy {

    static final double MAXIMUM_SIMILARITY = 0.65;

    public boolean isTooSimilar(GeneratedMission generated, List<Mission> existingMissions) {
        String generatedTitle = normalize(generated.title());
        String generatedContent = normalize(generated.title() + generated.description());

        return existingMissions.stream().anyMatch(existing ->
                generatedTitle.equals(normalize(existing.title()))
                        || jaccardBigrams(
                                generatedContent,
                                normalize(existing.title() + existing.description()))
                                >= MAXIMUM_SIMILARITY);
    }

    static double jaccardBigrams(String left, String right) {
        Set<String> leftBigrams = bigrams(left);
        Set<String> rightBigrams = bigrams(right);
        if (leftBigrams.isEmpty() && rightBigrams.isEmpty()) {
            return 1.0;
        }

        Set<String> intersection = new HashSet<>(leftBigrams);
        intersection.retainAll(rightBigrams);
        Set<String> union = new HashSet<>(leftBigrams);
        union.addAll(rightBigrams);
        return (double) intersection.size() / union.size();
    }

    static String normalize(String value) {
        return Normalizer.normalize(value, Normalizer.Form.NFC)
                .toUpperCase(Locale.ROOT)
                .replaceAll("[^가-힣A-Z0-9]", "");
    }

    private static Set<String> bigrams(String value) {
        Set<String> result = new HashSet<>();
        if (value.length() < 2) {
            if (!value.isEmpty()) {
                result.add(value);
            }
            return result;
        }
        for (int index = 0; index < value.length() - 1; index++) {
            result.add(value.substring(index, index + 2));
        }
        return result;
    }
}
