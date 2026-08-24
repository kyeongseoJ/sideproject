package com.novelty.mission;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.transaction.CannotCreateTransactionException;

import com.novelty.user.UserAuthenticationException;

class MissionPhase3ControllerTest {

    private static final String USER_KEY = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

    private MissionService service;
    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        service = mock(MissionService.class);
        mockMvc = MockMvcBuilders.standaloneSetup(new MissionController(service))
                .setControllerAdvice(new MissionExceptionHandler())
                .build();
    }

    @Test
    void savesAndGetsSettings() throws Exception {
        MissionSettingsResponse settings = new MissionSettingsResponse(AvailableTime.SHORT, 2);
        when(service.saveSettings(anyString(), any(MissionSettingsRequest.class))).thenReturn(settings);
        when(service.getSettings(USER_KEY)).thenReturn(settings);

        mockMvc.perform(put("/api/missions/settings")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"availableTime":"SHORT","dailyMissionLimit":2}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.availableTime").value("SHORT"))
                .andExpect(jsonPath("$.dailyMissionLimit").value(2));

        mockMvc.perform(get("/api/missions/settings")
                        .header("X-User-Key", USER_KEY))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.dailyMissionLimit").value(2));
    }

    @Test
    void returnsCreatedThenOkForDailyRecommendations() throws Exception {
        MissionTodayResponse response = today();
        when(service.recommendToday(USER_KEY))
                .thenReturn(new MissionRecommendationBatchResult(response, true))
                .thenReturn(new MissionRecommendationBatchResult(response, false));

        mockMvc.perform(post("/api/missions/today/recommendations")
                        .header("X-User-Key", USER_KEY))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.serviceDate").value("2026-08-20"))
                .andExpect(jsonPath("$.remainingSlots").value(1));

        mockMvc.perform(post("/api/missions/today/recommendations")
                        .header("X-User-Key", USER_KEY))
                .andExpect(status().isOk());
    }

    @Test
    void mapsInvalidBodyAuthenticationAndConflictFailures() throws Exception {
        mockMvc.perform(put("/api/missions/settings")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_MISSION_REQUEST"));

        when(service.getToday(null)).thenThrow(new UserAuthenticationException());
        mockMvc.perform(get("/api/missions/today"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_USER_KEY"));

        when(service.recommendToday(USER_KEY)).thenThrow(new MissionSettingsRequiredException());
        mockMvc.perform(post("/api/missions/today/recommendations")
                        .header("X-User-Key", USER_KEY))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("MISSION_SETTINGS_REQUIRED"));
    }

    @Test
    void hidesDatabaseAndTransactionDetails() throws Exception {
        when(service.getToday(USER_KEY))
                .thenThrow(new DataAccessResourceFailureException("sensitive sql"))
                .thenThrow(new CannotCreateTransactionException("connection details"))
                .thenThrow(new IllegalStateException("internal details"));

        for (int attempt = 0; attempt < 3; attempt++) {
            mockMvc.perform(get("/api/missions/today")
                            .header("X-User-Key", USER_KEY))
                    .andExpect(status().isInternalServerError())
                    .andExpect(jsonPath("$.code").value("MISSION_PROCESSING_FAILED"))
                    .andExpect(jsonPath("$.message").value(
                            "미션 정보를 처리하지 못했습니다. 잠시 후 다시 시도해 주세요."));
        }
    }

    @Test
    void legacyMissionEndpointsAreNotMapped() throws Exception {
        mockMvc.perform(post("/api/missions/random")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"availableTime\":\"SHORT\"}"))
                .andExpect(status().isNotFound());

        mockMvc.perform(patch("/api/missions/1/status")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"COMPLETED\"}"))
                .andExpect(status().isNotFound());
    }

    private MissionTodayResponse today() {
        return new MissionTodayResponse(
                LocalDate.of(2026, 8, 20),
                new MissionSettingsResponse(AvailableTime.SHORT, 1),
                0,
                1,
                List.of(),
                List.of());
    }
}
