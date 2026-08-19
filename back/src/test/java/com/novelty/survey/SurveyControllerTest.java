package com.novelty.survey;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.transaction.CannotCreateTransactionException;

class SurveyControllerTest {

    private SurveyService surveyService;
    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        surveyService = mock(SurveyService.class);
        mockMvc = MockMvcBuilders.standaloneSetup(new SurveyController(surveyService))
                .setControllerAdvice(new SurveyExceptionHandler())
                .build();
    }

    @Test
    void returnsCreatedForValidSurvey() throws Exception {
        when(surveyService.save(any(SurveyRequest.class))).thenReturn(SurveyResponse.saved(42L));

        mockMvc.perform(post("/api/surveys")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequestJson()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.surveyId").value(42))
                .andExpect(jsonPath("$.status").value("SAVED"));
    }

    @Test
    void returnsBadRequestForInvalidSurvey() throws Exception {
        when(surveyService.save(any(SurveyRequest.class)))
                .thenThrow(new InvalidSurveyException("관심 활동은 1개 이상 3개 이하로 선택해야 합니다."));

        mockMvc.perform(post("/api/surveys")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequestJson()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_SURVEY"))
                .andExpect(jsonPath("$.message")
                        .value("관심 활동은 1개 이상 3개 이하로 선택해야 합니다."));
    }

    @Test
    void returnsBadRequestForUnknownChoiceCode() throws Exception {
        mockMvc.perform(post("/api/surveys")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequestJson().replace("INDOOR", "UNKNOWN")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_SURVEY"));
    }

    @Test
    void returnsServerErrorWhenDatabaseSaveFails() throws Exception {
        when(surveyService.save(any(SurveyRequest.class)))
                .thenThrow(new DataAccessResourceFailureException("database unavailable"));

        mockMvc.perform(post("/api/surveys")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequestJson()))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.code").value("SURVEY_SAVE_FAILED"))
                .andExpect(jsonPath("$.message")
                        .value("선택을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요."));
    }

    @Test
    void returnsServerErrorWhenDatabaseTransactionCannotStart() throws Exception {
        when(surveyService.save(any(SurveyRequest.class)))
                .thenThrow(new CannotCreateTransactionException("database unavailable"));

        mockMvc.perform(post("/api/surveys")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequestJson()))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.code").value("SURVEY_SAVE_FAILED"))
                .andExpect(jsonPath("$.message")
                        .value("선택을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요."));
    }

    @Test
    void allowsLocalFrontendOrigin() throws Exception {
        when(surveyService.save(any(SurveyRequest.class))).thenReturn(SurveyResponse.saved(42L));

        mockMvc.perform(post("/api/surveys")
                        .header(HttpHeaders.ORIGIN, "http://localhost:7357")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequestJson()))
                .andExpect(status().isCreated())
                .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN,
                        "http://localhost:7357"));
    }

    private String validRequestJson() {
        return """
                {
                  "activityLevel": "INDOOR",
                  "socialActivity": "LOW",
                  "noveltyTolerance": "MEDIUM",
                  "interests": ["CREATIVE", "FOOD", "CULTURE"],
                  "energyLevel": "LOW"
                }
                """;
    }
}
