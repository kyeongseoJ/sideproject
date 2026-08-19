package com.novelty.personality;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.OffsetDateTime;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.transaction.CannotCreateTransactionException;

import com.novelty.user.UserAuthenticationException;
import com.novelty.user.UserPersonalityResponse;

class PersonalityControllerTest {

    private static final String USER_KEY = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

    private PersonalityService service;
    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        service = mock(PersonalityService.class);
        mockMvc = MockMvcBuilders.standaloneSetup(new PersonalityController(service))
                .setControllerAdvice(new PersonalityExceptionHandler())
                .build();
    }

    @Test
    void returnsCreatedForNewAnalysis() throws Exception {
        when(service.analyze(anyString(), any(PersonalityAnalysisRequest.class)))
                .thenReturn(new PersonalitySubmissionResult(successResponse(), true));

        mockMvc.perform(post("/api/personality-analyses")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequestJson()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.analysisId").value(42))
                .andExpect(jsonPath("$.status").value("ANALYZED"))
                .andExpect(jsonPath("$.personality.typeCode").value("QUIET_FOCUSER"))
                .andExpect(jsonPath("$.personality.indoorOutdoor").value("INDOOR"))
                .andExpect(jsonPath("$.personality.indoorOutdoorScore").value(-1))
                .andExpect(jsonPath("$.personality.physicalActivityLevel").value("LOW"))
                .andExpect(jsonPath("$.personality.analysisVersion").value("PERSONALITY_V2"));
    }

    @Test
    void returnsOkForIdempotentRetry() throws Exception {
        when(service.analyze(anyString(), any(PersonalityAnalysisRequest.class)))
                .thenReturn(new PersonalitySubmissionResult(successResponse(), false));

        mockMvc.perform(post("/api/personality-analyses")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequestJson()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.analysisId").value(42));
    }

    @Test
    void returnsBadRequestForInvalidAnswers() throws Exception {
        when(service.analyze(anyString(), any(PersonalityAnalysisRequest.class)))
                .thenThrow(new InvalidPersonalityAnswersException(
                        PersonalityValidationError.INTERESTS_REQUIRED,
                        "관심 분야를 한 개 이상 선택해야 합니다."));

        mockMvc.perform(post("/api/personality-analyses")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequestJson()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_PERSONALITY_ANSWERS"));
    }

    @Test
    void returnsBadRequestForMissingSubmissionKey() throws Exception {
        when(service.analyze(anyString(), any(PersonalityAnalysisRequest.class)))
                .thenThrow(new InvalidSubmissionKeyException());

        mockMvc.perform(post("/api/personality-analyses")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequestJson()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_SUBMISSION_KEY"));
    }

    @Test
    void returnsUnauthorizedForInvalidUserKey() throws Exception {
        when(service.analyze(any(), any(PersonalityAnalysisRequest.class)))
                .thenThrow(new UserAuthenticationException());

        mockMvc.perform(post("/api/personality-analyses")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequestJson()))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_USER_KEY"));
    }

    @Test
    void returnsConflictWhenInitialAnalysisAlreadyExists() throws Exception {
        when(service.analyze(anyString(), any(PersonalityAnalysisRequest.class)))
                .thenThrow(new PersonalityAlreadyAnalyzedException());

        expectConflict("PERSONALITY_ALREADY_ANALYZED");
    }

    @Test
    void returnsConflictWhenReanalysisHasNoExistingProfile() throws Exception {
        when(service.analyze(anyString(), any(PersonalityAnalysisRequest.class)))
                .thenThrow(new PersonalityNotAnalyzedException());

        expectConflict("PERSONALITY_NOT_ANALYZED");
    }

    @Test
    void returnsConflictForReusedSubmissionKeyWithDifferentAnswers() throws Exception {
        when(service.analyze(anyString(), any(PersonalityAnalysisRequest.class)))
                .thenThrow(new SubmissionKeyConflictException());

        expectConflict("SUBMISSION_KEY_CONFLICT");
    }

    @Test
    void returnsBadRequestForUnknownEnumOrMalformedJson() throws Exception {
        mockMvc.perform(post("/api/personality-analyses")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequestJson().replace("INDOOR", "UNKNOWN")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_PERSONALITY_ANSWERS"));

        mockMvc.perform(post("/api/personality-analyses")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_PERSONALITY_ANSWERS"));
    }

    @Test
    void returnsSafeServerErrorForDatabaseOrTransactionFailure() throws Exception {
        when(service.analyze(anyString(), any(PersonalityAnalysisRequest.class)))
                .thenThrow(new DataAccessResourceFailureException("contains sensitive SQL"))
                .thenThrow(new CannotCreateTransactionException("contains connection details"));

        mockMvc.perform(post("/api/personality-analyses")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequestJson()))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.code").value("PERSONALITY_SAVE_FAILED"))
                .andExpect(jsonPath("$.message").value(
                        "성향 분석을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요."));

        mockMvc.perform(post("/api/personality-analyses")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequestJson()))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.code").value("PERSONALITY_SAVE_FAILED"));
    }

    @Test
    void allowsLocalFrontendOrigin() throws Exception {
        when(service.analyze(anyString(), any(PersonalityAnalysisRequest.class)))
                .thenReturn(new PersonalitySubmissionResult(successResponse(), true));

        mockMvc.perform(post("/api/personality-analyses")
                        .header("X-User-Key", USER_KEY)
                        .header(HttpHeaders.ORIGIN, "http://localhost:3000")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequestJson()))
                .andExpect(status().isCreated())
                .andExpect(header().string(
                        HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN,
                        "http://localhost:3000"));
    }

    private void expectConflict(String code) throws Exception {
        mockMvc.perform(post("/api/personality-analyses")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequestJson()))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value(code));
    }

    private PersonalityAnalysisResponse successResponse() {
        UserPersonalityResponse personality = new UserPersonalityResponse(
                "QUIET_FOCUSER",
                "고요한 몰입가",
                "익숙하고 조용한 공간에서 혼자 집중할 때 편안해요.",
                IndoorOutdoor.INDOOR,
                -1,
                SocialLevel.LOW,
                -1,
                PhysicalActivityLevel.LOW,
                0,
                NoveltyLevel.MEDIUM,
                1,
                ExecutionStyle.PLANNED,
                List.of(Interest.CREATIVE, Interest.LEARNING),
                "PERSONALITY_V2",
                OffsetDateTime.parse("2026-08-19T17:15:00+09:00"));
        return PersonalityAnalysisResponse.analyzed(42L, personality);
    }

    private String validRequestJson() {
        return """
                {
                  "submissionKey": "2c3ed6f9-5780-4da8-9c73-830ce137b899",
                  "analysisMode": "INITIAL",
                  "indoorOutdoor": "INDOOR",
                  "socialLevel": "LOW",
                  "physicalActivityLevel": "LOW",
                  "noveltyLevel": "MEDIUM",
                  "interests": ["CREATIVE", "LEARNING"],
                  "executionStyle": "PLANNED"
                }
                """;
    }
}
