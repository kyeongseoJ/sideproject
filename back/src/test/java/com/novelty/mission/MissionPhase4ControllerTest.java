package com.novelty.mission;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import com.novelty.user.UserAuthenticationException;

class MissionPhase4ControllerTest {

    private static final String USER_KEY = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

    private UserMissionService service;
    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        service = mock(UserMissionService.class);
        mockMvc = MockMvcBuilders.standaloneSetup(new UserMissionController(service))
                .setControllerAdvice(new MissionExceptionHandler())
                .build();
    }

    @Test
    void exposesSelectCancelReplaceAndCompleteActions() throws Exception {
        when(service.select(USER_KEY, 101)).thenReturn(action(101, MissionStatus.SELECTED, false));
        when(service.cancel(USER_KEY, 101)).thenReturn(action(101, MissionStatus.CANCELLED, false));
        when(service.replace(anyString(), anyLong(), any(ReplacementMissionRequest.class)))
                .thenReturn(action(102, MissionStatus.SELECTED, false));
        when(service.complete(USER_KEY, 102)).thenReturn(action(102, MissionStatus.COMPLETED, true));

        mockMvc.perform(post("/api/user-missions/101/select").header("X-User-Key", USER_KEY))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mission.status").value("SELECTED"));
        mockMvc.perform(post("/api/user-missions/101/cancel").header("X-User-Key", USER_KEY))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mission.status").value("CANCELLED"));
        mockMvc.perform(post("/api/user-missions/101/replace")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"replacementUserMissionId\":102}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mission.userMissionId").value(102));
        mockMvc.perform(post("/api/user-missions/102/complete").header("X-User-Key", USER_KEY))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.idempotent").value(true));
    }

    @Test
    void mapsAuthenticationOwnershipLimitAndTransitionFailures() throws Exception {
        when(service.select(null, 101)).thenThrow(new UserAuthenticationException());
        mockMvc.perform(post("/api/user-missions/101/select"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_USER_KEY"));

        when(service.select(USER_KEY, 999)).thenThrow(new UserMissionNotFoundException());
        mockMvc.perform(post("/api/user-missions/999/select").header("X-User-Key", USER_KEY))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("USER_MISSION_NOT_FOUND"));

        when(service.select(USER_KEY, 101)).thenThrow(new DailyLimitReachedException());
        mockMvc.perform(post("/api/user-missions/101/select").header("X-User-Key", USER_KEY))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("DAILY_LIMIT_REACHED"));

        when(service.cancel(USER_KEY, 101)).thenThrow(new InvalidMissionTransitionException());
        mockMvc.perform(post("/api/user-missions/101/cancel").header("X-User-Key", USER_KEY))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("INVALID_MISSION_TRANSITION"));
    }

    @Test
    void mapsMalformedReplacementAndUnavailableCandidate() throws Exception {
        mockMvc.perform(post("/api/user-missions/101/replace")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_MISSION_REQUEST"));

        when(service.replace(anyString(), anyLong(), any(ReplacementMissionRequest.class)))
                .thenThrow(new ReplacementNotAvailableException());
        mockMvc.perform(post("/api/user-missions/101/replace")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"replacementUserMissionId\":102}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("REPLACEMENT_NOT_AVAILABLE"));
    }

    @Test
    void hidesDatabaseFailureDetails() throws Exception {
        when(service.complete(USER_KEY, 101))
                .thenThrow(new DataAccessResourceFailureException("sensitive sql"));
        mockMvc.perform(post("/api/user-missions/101/complete")
                        .header("X-User-Key", USER_KEY))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.code").value("MISSION_PROCESSING_FAILED"))
                .andExpect(jsonPath("$.message").value(
                        "미션 정보를 처리하지 못했습니다. 잠시 후 다시 시도해 주세요."));
    }

    private UserMissionActionResponse action(long id, MissionStatus status, boolean idempotent) {
        MissionSettingsResponse settings = new MissionSettingsResponse(AvailableTime.SHORT, 2);
        UserMissionResponse mission = new UserMissionResponse(
                id, 1, "미션", "설명", MissionCategory.MOVEMENT,
                1, 5, 1, 1, 2, 2, MissionSourceType.BASE,
                0.8, 0.8, status, OffsetDateTime.parse("2026-08-20T09:00:00+09:00"));
        MissionTodayResponse today = new MissionTodayResponse(
                LocalDate.of(2026, 8, 20), settings, 0, 1, List.of(), List.of());
        return new UserMissionActionResponse(mission, today, idempotent);
    }
}
