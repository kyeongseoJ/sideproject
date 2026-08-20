package com.novelty.mission;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.OffsetDateTime;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import com.novelty.user.UserAuthenticationException;

class MissionPhase5ControllerTest {

    private static final String USER_KEY = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

    private UserMissionService service;
    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        service = mock(UserMissionService.class);
        mockMvc = MockMvcBuilders.standaloneSetup(new MissionSummaryController(service))
                .setControllerAdvice(new MissionExceptionHandler())
                .build();
    }

    @Test
    void returnsCompletionAndCategorySummary() throws Exception {
        when(service.getSummary(USER_KEY)).thenReturn(new MissionSummaryResponse(
                6,
                5,
                "BALANCED_COORDINATOR",
                List.of(new MissionCategoryStatResponse(
                        MissionCategory.MOVEMENT,
                        4,
                        OffsetDateTime.parse("2026-08-20T09:00:00+09:00")))));

        mockMvc.perform(get("/api/missions/summary").header("X-User-Key", USER_KEY))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.completedMissionCount").value(6))
                .andExpect(jsonPath("$.lastPersonalityAdaptedCount").value(5))
                .andExpect(jsonPath("$.personalityCode").value("BALANCED_COORDINATOR"))
                .andExpect(jsonPath("$.categoryStats[0].category").value("MOVEMENT"))
                .andExpect(jsonPath("$.categoryStats[0].completedCount").value(4));
    }

    @Test
    void mapsAuthenticationPersonalityAndDatabaseFailures() throws Exception {
        doThrow(new UserAuthenticationException()).when(service).getSummary(null);
        mockMvc.perform(get("/api/missions/summary"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_USER_KEY"));

        doThrow(new PersonalityRequiredException()).when(service).getSummary(USER_KEY);
        mockMvc.perform(get("/api/missions/summary").header("X-User-Key", USER_KEY))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("PERSONALITY_REQUIRED"));

        doThrow(new DataAccessResourceFailureException("sensitive sql"))
                .when(service).getSummary(USER_KEY);
        mockMvc.perform(get("/api/missions/summary").header("X-User-Key", USER_KEY))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.code").value("MISSION_PROCESSING_FAILED"));
    }
}
