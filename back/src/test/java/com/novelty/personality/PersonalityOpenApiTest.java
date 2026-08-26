package com.novelty.personality;

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
class PersonalityOpenApiTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void exposesPersonalityAnalysisAndCurrentUserPaths() throws Exception {
        mockMvc.perform(get("/v3/api-docs"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.paths['/api/personality-analyses'].post").exists())
                .andExpect(jsonPath("$.paths['/api/personality-analyses'].post.responses['201']").exists())
                .andExpect(jsonPath("$.paths['/api/personality-analyses'].post.responses['409']").exists())
                .andExpect(jsonPath("$.components.schemas.PersonalityAnalysisRequest.properties.submissionKey.format")
                        .value("uuid"))
                .andExpect(jsonPath("$.components.schemas.PersonalityAnalysisRequest.properties.submissionKey.example")
                        .value("2c3ed6f9-5780-4da8-9c73-830ce137b899"))
                .andExpect(jsonPath("$.paths['/api/users/me'].get").exists());
    }
}
