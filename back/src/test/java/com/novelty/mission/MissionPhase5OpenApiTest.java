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
class MissionPhase5OpenApiTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void exposesMissionSummaryAndCompletionEffectSchema() throws Exception {
        mockMvc.perform(get("/v3/api-docs"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.paths['/api/missions/summary'].get").exists())
                .andExpect(jsonPath("$.components.schemas.MissionSummaryResponse").exists())
                .andExpect(jsonPath("$.components.schemas.MissionCompletionEffectResponse.properties.worldGrowth").exists())
                .andExpect(jsonPath("$.components.schemas.WorldGrowthResponse").exists());
    }
}
