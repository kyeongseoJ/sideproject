package com.novelty.survey;

import java.util.HashSet;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SurveyService {

    private final SurveyRepository surveyRepository;

    public SurveyService(SurveyRepository surveyRepository) {
        this.surveyRepository = surveyRepository;
    }

    @Transactional
    public SurveyResponse save(SurveyRequest request) {
        validate(request);
        return SurveyResponse.saved(surveyRepository.save(request));
    }

    private void validate(SurveyRequest request) {
        if (request == null) {
            throw new InvalidSurveyException("설문 응답이 필요합니다.");
        }

        if (request.activityLevel() == null
                || request.socialActivity() == null
                || request.noveltyTolerance() == null
                || request.energyLevel() == null) {
            throw new InvalidSurveyException("모든 단일 선택 문항에 응답해야 합니다.");
        }

        validateInterests(request.interests());
    }

    private void validateInterests(List<SurveyRequest.Interest> interests) {
        if (interests == null || interests.isEmpty() || interests.size() > 3) {
            throw new InvalidSurveyException("관심 활동은 1개 이상 3개 이하로 선택해야 합니다.");
        }

        if (new HashSet<>(interests).size() != interests.size()) {
            throw new InvalidSurveyException("관심 활동은 중복해서 선택할 수 없습니다.");
        }
    }
}
