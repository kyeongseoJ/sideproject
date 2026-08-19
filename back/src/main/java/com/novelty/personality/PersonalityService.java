package com.novelty.personality;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.novelty.user.UserPersonalityResponse;
import com.novelty.user.UserService;

@Service
public class PersonalityService {

    private final PersonalityRepository personalityRepository;
    private final UserService userService;
    private final Clock clock;
    private final PersonalityAnalyzer analyzer;

    public PersonalityService(
            PersonalityRepository personalityRepository,
            UserService userService,
            Clock clock) {
        this.personalityRepository = personalityRepository;
        this.userService = userService;
        this.clock = clock;
        this.analyzer = new PersonalityAnalyzer();
    }

    @Transactional
    public PersonalitySubmissionResult analyze(
            String userKey,
            PersonalityAnalysisRequest request) {
        String submissionKey = normalizeSubmissionKey(request);
        long userId = userService.requireUserId(userKey);
        PersonalityAnswers answers = validateAndCanonicalizeAnswers(request);
        PersonalityAnalysis analysis = analyzer.analyze(answers);

        personalityRepository.lockUser(userId);
        Optional<StoredPersonalitySubmission> existing =
                personalityRepository.findSubmission(userId, submissionKey);
        if (existing.isPresent()) {
            return existingResult(existing.orElseThrow(), request.analysisMode(), answers, userId);
        }

        validateAnalysisMode(request.analysisMode());
        validateProfileState(userId, request.analysisMode());

        OffsetDateTime analyzedAt = OffsetDateTime.now(clock);
        long analysisId = personalityRepository.nextAnalysisId();
        personalityRepository.insertSubmission(
                analysisId,
                userId,
                submissionKey,
                request.analysisMode(),
                answers,
                analyzedAt);

        if (request.analysisMode() == AnalysisMode.INITIAL) {
            personalityRepository.insertProfile(userId, analysisId, analysis, analyzedAt);
        } else {
            personalityRepository.updateProfile(userId, analysisId, analysis, analyzedAt);
        }
        personalityRepository.replaceProfileInterests(userId, answers.interests());
        personalityRepository.touchUser(userId, analyzedAt);

        return new PersonalitySubmissionResult(
                PersonalityAnalysisResponse.analyzed(
                        analysisId,
                        UserPersonalityResponse.from(analysis, analyzedAt)),
                true);
    }

    private PersonalitySubmissionResult existingResult(
            StoredPersonalitySubmission existing,
            AnalysisMode requestedMode,
            PersonalityAnswers requestedAnswers,
            long userId) {
        if (!existing.matches(requestedMode, requestedAnswers)) {
            throw new SubmissionKeyConflictException();
        }

        PersonalityAnalysis existingAnalysis = analyzer.analyze(existing.answers());
        personalityRepository.touchUser(userId, OffsetDateTime.now(clock));
        return new PersonalitySubmissionResult(
                PersonalityAnalysisResponse.analyzed(
                        existing.analysisId(),
                        UserPersonalityResponse.from(existingAnalysis, existing.analyzedAt())),
                false);
    }

    private String normalizeSubmissionKey(PersonalityAnalysisRequest request) {
        if (request == null || request.submissionKey() == null) {
            throw new InvalidSubmissionKeyException();
        }
        try {
            UUID uuid = UUID.fromString(request.submissionKey());
            String normalized = uuid.toString();
            if (!normalized.equalsIgnoreCase(request.submissionKey())) {
                throw new InvalidSubmissionKeyException();
            }
            return normalized;
        } catch (IllegalArgumentException exception) {
            throw new InvalidSubmissionKeyException();
        }
    }

    private PersonalityAnswers validateAndCanonicalizeAnswers(PersonalityAnalysisRequest request) {
        validateAnalysisMode(request.analysisMode());
        PersonalityAnalysis validated = analyzer.analyze(request.toAnswers());
        List<Interest> canonicalInterests = validated.interests().stream()
                .sorted(Comparator.comparing(Enum::name))
                .toList();
        return new PersonalityAnswers(
                validated.indoorOutdoor(),
                validated.socialLevel(),
                validated.physicalActivityLevel(),
                validated.noveltyLevel(),
                canonicalInterests,
                validated.executionStyle());
    }

    private void validateAnalysisMode(AnalysisMode analysisMode) {
        if (analysisMode == null) {
            throw new InvalidPersonalityAnswersException(
                    PersonalityValidationError.ANALYSIS_MODE_REQUIRED,
                    "분석 방식이 필요합니다.");
        }
    }

    private void validateProfileState(long userId, AnalysisMode analysisMode) {
        boolean profileExists = personalityRepository.profileExists(userId);
        if (analysisMode == AnalysisMode.INITIAL && profileExists) {
            throw new PersonalityAlreadyAnalyzedException();
        }
        if (analysisMode == AnalysisMode.REANALYSIS && !profileExists) {
            throw new PersonalityNotAnalyzedException();
        }
    }
}
