package com.novelty.mission;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "spring.datasource.url=${DB_URL:jdbc:postgresql://localhost:5432/postgres}",
        "spring.datasource.username=${DB_USERNAME:test}",
        "spring.datasource.password=${DB_PASSWORD:test}"
})
@AutoConfigureMockMvc
class MissionPhase4OpenApiTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void exposesAllUserMissionActionPaths() throws Exception {
        mockMvc.perform(get("/v3/api-docs"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.paths['/api/user-missions/{userMissionId}/select'].post").exists())
                .andExpect(jsonPath("$.paths['/api/user-missions/{userMissionId}/cancel'].post").exists())
                .andExpect(jsonPath("$.paths['/api/user-missions/{userMissionId}/replace'].post").exists())
                .andExpect(jsonPath("$.paths['/api/user-missions/{userMissionId}/complete'].post").exists());
    }
}
