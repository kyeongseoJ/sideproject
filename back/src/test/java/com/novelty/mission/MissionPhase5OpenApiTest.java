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
        "spring.datasource.url=jdbc:oracle:thin:@localhost:1521:XE",
        "spring.datasource.username=openapi-test",
        "spring.datasource.password=openapi-test"
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
                .andExpect(jsonPath("$.components.schemas.MissionCompletionEffectResponse").exists());
    }
}
