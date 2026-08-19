package com.novelty.mission;

import java.util.List;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

@Service
public class MissionLlmGenerationService {

    private static final double MINIMUM_PERSONALITY_DISTANCE = 0.5;

    private final MissionRepository missionRepository;
    private final MissionContentGenerator contentGenerator;
    private final MissionSimilarityPolicy similarityPolicy;

    public MissionLlmGenerationService(
            MissionRepository missionRepository,
            MissionContentGenerator contentGenerator,
            MissionSimilarityPolicy similarityPolicy) {
        this.missionRepository = missionRepository;
        this.contentGenerator = contentGenerator;
        this.similarityPolicy = similarityPolicy;
    }

    public String generateAtMilestone(long userId, int milestone, UserMissionVector userVector) {
        if (milestone < 5 || milestone % 5 != 0) {
            return "NOT_DUE";
        }
        if (!contentGenerator.isAvailable()) {
            return "NOT_CONFIGURED";
        }
        if (!missionRepository.claimGeneration(userId, milestone, contentGenerator.modelName())) {
            return "ALREADY_PROCESSED";
        }

        try {
            List<Mission> existingMissions = missionRepository.findAllEnabled();
            GeneratedMission generated = contentGenerator.generate(userVector, existingMissions);
            if (userVector.distanceFrom(generated) < MINIMUM_PERSONALITY_DISTANCE) {
                missionRepository.failGeneration(userId, milestone, "TOO_CLOSE_TO_PERSONALITY");
                return "REJECTED_TOO_CLOSE";
            }
            if (similarityPolicy.isTooSimilar(generated, existingMissions)) {
                missionRepository.failGeneration(userId, milestone, "TOO_SIMILAR");
                return "REJECTED_SIMILAR";
            }
            long missionId = missionRepository.insertGenerated(generated);
            missionRepository.completeGeneration(userId, milestone, missionId);
            return "CREATED";
        } catch (DataIntegrityViolationException exception) {
            missionRepository.failGeneration(userId, milestone, "DUPLICATE");
            return "REJECTED_DUPLICATE";
        } catch (RuntimeException exception) {
            missionRepository.failGeneration(userId, milestone, "GENERATION_FAILED");
            return "FAILED";
        }
    }
}
