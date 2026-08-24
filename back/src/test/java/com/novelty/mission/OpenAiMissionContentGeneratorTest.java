package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpResponse;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.json.JsonMapper;

class OpenAiMissionContentGeneratorTest {

    @Test
    void parsesStructuredOutputFromResponsesApi() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        @SuppressWarnings("unchecked")
        HttpResponse<String> response = mock(HttpResponse.class);
        JsonMapper jsonMapper = JsonMapper.builder().build();
        String generatedJson = jsonMapper.writeValueAsString(Map.ofEntries(
                Map.entry("title", "새로운 미션"),
                Map.entry("description", "처음 하는 행동을 해 보세요"),
                Map.entry("category", "CREATIVE"),
                Map.entry("difficulty", 1),
                Map.entry("estimatedMinutes", 10),
                Map.entry("indoorOutdoor", 1),
                Map.entry("socialLevel", 1),
                Map.entry("activityLevel", 2),
                Map.entry("noveltyLevel", 2),
                Map.entry("actionType", "CREATE"),
                Map.entry("creativityLevel", 2),
                Map.entry("unpredictabilityLevel", 2),
                Map.entry("comfortZoneDistance", 2),
                Map.entry("costLevel", 0),
                Map.entry("tags", List.of("CREATE", "ART"))));
        when(response.statusCode()).thenReturn(200);
        when(response.body()).thenReturn(jsonMapper.writeValueAsString(Map.of(
                "output", List.of(Map.of(
                        "content", List.of(Map.of(
                                "type", "output_text",
                                "text", generatedJson)))))));
        doReturn(response).when(httpClient).send(any(), any());
        OpenAiMissionContentGenerator generator = new OpenAiMissionContentGenerator(
                jsonMapper,
                httpClient,
                "test-api-key",
                "test-model",
                URI.create("https://api.openai.test/v1/responses"));

        GeneratedMission generated = generator.generate(
                new UserMissionVector(-1, -1, 0, 0, 5), List.of());

        assertThat(generated.title()).isEqualTo("새로운 미션");
        assertThat(generated.indoorOutdoor()).isEqualTo(1);
        assertThat(generated.activityLevel()).isEqualTo(2);
        assertThat(generated.actionType()).isEqualTo(MissionActionType.CREATE);
        assertThat(generated.tags()).containsExactlyInAnyOrder("CREATE", "ART");
    }
}
