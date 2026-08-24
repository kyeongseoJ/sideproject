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
class MissionPhase3OpenApiTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void exposesSettingsTodayAndRecommendationPaths() throws Exception {
        mockMvc.perform(get("/v3/api-docs"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.paths['/api/missions/settings'].get").exists())
                .andExpect(jsonPath("$.paths['/api/missions/settings'].put").exists())
                .andExpect(jsonPath("$.paths['/api/missions/today'].get").exists())
                .andExpect(jsonPath("$.paths['/api/missions/today/recommendations'].post").exists())
                .andExpect(jsonPath(
                        "$.paths['/api/missions/today/recommendations'].post.responses['201']")
                        .exists())
                .andExpect(jsonPath(
                        "$.paths['/api/missions/today/recommendations'].post.responses['409']")
                        .exists())
                .andExpect(jsonPath("$.paths['/api/missions/random']").doesNotExist())
                .andExpect(jsonPath("$.paths['/api/missions/{missionId}/status']").doesNotExist())
                .andExpect(jsonPath("$.paths['/api/surveys']").doesNotExist());
    }
}
