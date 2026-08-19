package com.novelty.survey;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class SurveyServiceTest {

    private SurveyRepository surveyRepository;
    private SurveyService surveyService;

    @BeforeEach
    void setUp() {
        surveyRepository = mock(SurveyRepository.class);
        surveyService = new SurveyService(surveyRepository);
    }

    @Test
    void savesValidSurvey() {
        SurveyRequest request = validRequest();
        when(surveyRepository.save(request)).thenReturn(42L);

        SurveyResponse response = surveyService.save(request);

        assertEquals(42L, response.surveyId());
        assertEquals("SAVED", response.status());
        verify(surveyRepository).save(request);
    }

    @Test
    void rejectsMissingRequest() {
        InvalidSurveyException exception = assertThrows(
                InvalidSurveyException.class,
                () -> surveyService.save(null));

        assertEquals("설문 응답이 필요합니다.", exception.getMessage());
        verifyNoInteractions(surveyRepository);
    }

    @Test
    void rejectsMissingSingleChoice() {
        List<SurveyRequest> invalidRequests = List.of(
                new SurveyRequest(null, SurveyRequest.SocialActivity.LOW,
                        SurveyRequest.NoveltyTolerance.MEDIUM,
                        List.of(SurveyRequest.Interest.CREATIVE), SurveyRequest.EnergyLevel.LOW),
                new SurveyRequest(SurveyRequest.ActivityLevel.INDOOR, null,
                        SurveyRequest.NoveltyTolerance.MEDIUM,
                        List.of(SurveyRequest.Interest.CREATIVE), SurveyRequest.EnergyLevel.LOW),
                new SurveyRequest(SurveyRequest.ActivityLevel.INDOOR, SurveyRequest.SocialActivity.LOW,
                        null, List.of(SurveyRequest.Interest.CREATIVE), SurveyRequest.EnergyLevel.LOW),
                new SurveyRequest(SurveyRequest.ActivityLevel.INDOOR, SurveyRequest.SocialActivity.LOW,
                        SurveyRequest.NoveltyTolerance.MEDIUM,
                        List.of(SurveyRequest.Interest.CREATIVE), null));

        for (SurveyRequest request : invalidRequests) {
            InvalidSurveyException exception = assertThrows(
                    InvalidSurveyException.class,
                    () -> surveyService.save(request));
            assertEquals("모든 단일 선택 문항에 응답해야 합니다.", exception.getMessage());
        }

        verifyNoInteractions(surveyRepository);
    }

    @Test
    void rejectsInvalidInterestCount() {
        List<List<SurveyRequest.Interest>> invalidInterests = List.of(
                List.of(),
                List.of(
                        SurveyRequest.Interest.MOVEMENT,
                        SurveyRequest.Interest.CREATIVE,
                        SurveyRequest.Interest.FOOD,
                        SurveyRequest.Interest.LEARNING));

        for (List<SurveyRequest.Interest> interests : invalidInterests) {
            SurveyRequest request = new SurveyRequest(
                    SurveyRequest.ActivityLevel.INDOOR,
                    SurveyRequest.SocialActivity.LOW,
                    SurveyRequest.NoveltyTolerance.MEDIUM,
                    interests,
                    SurveyRequest.EnergyLevel.LOW);

            InvalidSurveyException exception = assertThrows(
                    InvalidSurveyException.class,
                    () -> surveyService.save(request));
            assertEquals("관심 활동은 1개 이상 3개 이하로 선택해야 합니다.", exception.getMessage());
        }

        verifyNoInteractions(surveyRepository);
    }

    @Test
    void rejectsDuplicateInterests() {
        SurveyRequest request = new SurveyRequest(
                SurveyRequest.ActivityLevel.INDOOR,
                SurveyRequest.SocialActivity.LOW,
                SurveyRequest.NoveltyTolerance.MEDIUM,
                List.of(SurveyRequest.Interest.CREATIVE, SurveyRequest.Interest.CREATIVE),
                SurveyRequest.EnergyLevel.LOW);

        InvalidSurveyException exception = assertThrows(
                InvalidSurveyException.class,
                () -> surveyService.save(request));

        assertEquals("관심 활동은 중복해서 선택할 수 없습니다.", exception.getMessage());
        verifyNoInteractions(surveyRepository);
    }

    private SurveyRequest validRequest() {
        return new SurveyRequest(
                SurveyRequest.ActivityLevel.INDOOR,
                SurveyRequest.SocialActivity.LOW,
                SurveyRequest.NoveltyTolerance.MEDIUM,
                List.of(
                        SurveyRequest.Interest.CREATIVE,
                        SurveyRequest.Interest.FOOD,
                        SurveyRequest.Interest.CULTURE),
                SurveyRequest.EnergyLevel.LOW);
    }
}
