package com.novelty.world;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import com.novelty.user.UserAuthenticationException;

class WorldControllerTest {

    private static final String USER_KEY = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

    private WorldProgressService service;
    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        service = mock(WorldProgressService.class);
        mockMvc = MockMvcBuilders.standaloneSetup(new WorldController(service))
                .setControllerAdvice(new WorldExceptionHandler())
                .build();
    }

    @Test
    void returnsWorldSnapshot() throws Exception {
        when(service.getSnapshot(USER_KEY)).thenReturn(new WorldSnapshotResponse(List.of(
                new WorldObjectProgressResponse(
                        "BOOKSHELF", "LEARNING", "책장", 2, 60, 120, 5))));

        mockMvc.perform(get("/api/world").header("X-User-Key", USER_KEY))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.objects[0].objectCode").value("BOOKSHELF"))
                .andExpect(jsonPath("$.objects[0].level").value(2))
                .andExpect(jsonPath("$.objects[0].nextLevelRequiredExp").value(120));
    }

    @Test
    void returnsUnauthorizedWithoutValidUser() throws Exception {
        when(service.getSnapshot(null)).thenThrow(new UserAuthenticationException());

        mockMvc.perform(get("/api/world"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_USER_KEY"));
    }

    @Test
    void hidesDatabaseDetails() throws Exception {
        when(service.getSnapshot(USER_KEY))
                .thenThrow(new DataAccessResourceFailureException("sensitive sql"));

        mockMvc.perform(get("/api/world").header("X-User-Key", USER_KEY))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.code").value("WORLD_PROCESSING_FAILED"))
                .andExpect(jsonPath("$.message").value(
                        "월드 정보를 처리하지 못했습니다. 잠시 후 다시 시도해 주세요."));
    }
}
