package com.novelty.mission;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

@Component
public class OpenAiMissionContentGenerator implements MissionContentGenerator {

    private static final String INSTRUCTIONS = """
            당신은 노벨티 서비스의 행동 활성화 미션 작성자입니다.
            사용자의 현재 성향 벡터와 거리가 먼, 안전하고 합법적이며 일상에서 수행 가능한
            한국어 미션 하나를 만드세요. 의료·치료 효과를 약속하거나 위험, 금전 결제,
            개인정보 공개, 타인에게 부담을 주는 행동을 포함하지 마세요.
            기존 미션과 제목이나 행동 핵심이 겹치지 않아야 합니다.
            """;

    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;
    private final String apiKey;
    private final String model;
    private final URI responsesUri;

    @Autowired
    public OpenAiMissionContentGenerator(
            ObjectMapper objectMapper,
            @Value("${novelty.openai.api-key:}") String apiKey,
            @Value("${novelty.openai.model:}") String model,
            @Value("${novelty.openai.base-url:https://api.openai.com/v1}") String baseUrl) {
        this(objectMapper, HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build(), apiKey, model, URI.create(baseUrl + "/responses"));
    }

    OpenAiMissionContentGenerator(
            ObjectMapper objectMapper,
            HttpClient httpClient,
            String apiKey,
            String model,
            URI responsesUri) {
        this.objectMapper = objectMapper;
        this.httpClient = httpClient;
        this.apiKey = apiKey;
        this.model = model;
        this.responsesUri = responsesUri;
    }

    @Override
    public boolean isAvailable() {
        return !apiKey.isBlank() && !model.isBlank();
    }

    @Override
    public String modelName() {
        return model;
    }

    @Override
    public GeneratedMission generate(UserMissionVector userVector, List<Mission> existingMissions) {
        if (!isAvailable()) {
            throw new IllegalStateException("OpenAI mission generation is not configured.");
        }

        HttpRequest request = HttpRequest.newBuilder(responsesUri)
                .timeout(Duration.ofSeconds(45))
                .header("Authorization", "Bearer " + apiKey)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(requestBody(userVector, existingMissions)))
                .build();
        try {
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new IllegalStateException("OpenAI Responses API returned HTTP " + response.statusCode());
            }
            return parseGeneratedMission(response.body());
        } catch (IOException exception) {
            throw new IllegalStateException("OpenAI Responses API could not be reached.", exception);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("OpenAI Responses API request was interrupted.", exception);
        }
    }

    private String requestBody(UserMissionVector vector, List<Mission> existingMissions) {
        String existingTitles = existingMissions.stream()
                .map(Mission::title)
                .limit(200)
                .toList()
                .toString();
        String input = """
                사용자 벡터: indoorOutdoor=%d, socialLevel=%d, activityLevel=%d, noveltyLevel=%d
                기존 미션 제목: %s
                각 벡터 범위는 indoorOutdoor/socialLevel=-1..1, activityLevel/noveltyLevel=0..2입니다.
                사용자 벡터와 반대 방향인 미션을 하나 생성하세요.
                """.formatted(
                vector.indoorOutdoor(),
                vector.socialLevel(),
                vector.activityLevel(),
                vector.noveltyLevel(),
                existingTitles);

        Map<String, Object> schema = Map.of(
                "type", "object",
                "additionalProperties", false,
                "required", List.of(
                        "title", "description", "category", "difficulty", "estimatedMinutes",
                        "indoorOutdoor", "socialLevel", "activityLevel", "noveltyLevel"),
                "properties", Map.of(
                        "title", Map.of("type", "string", "maxLength", 100),
                        "description", Map.of("type", "string", "maxLength", 500),
                        "category", Map.of("type", "string", "enum", List.of(
                                "MOVEMENT", "CREATIVE", "FOOD", "LEARNING",
                                "SOCIAL", "OUTDOOR", "ORGANIZING", "CULTURE")),
                        "difficulty", Map.of("type", "integer", "minimum", 1, "maximum", 3),
                        "estimatedMinutes", Map.of("type", "integer", "minimum", 1, "maximum", 180),
                        "indoorOutdoor", Map.of("type", "integer", "minimum", -1, "maximum", 1),
                        "socialLevel", Map.of("type", "integer", "minimum", -1, "maximum", 1),
                        "activityLevel", Map.of("type", "integer", "minimum", 0, "maximum", 2),
                        "noveltyLevel", Map.of("type", "integer", "minimum", 0, "maximum", 2)));
        Map<String, Object> body = Map.of(
                "model", model,
                "store", false,
                "instructions", INSTRUCTIONS,
                "input", input,
                "text", Map.of("format", Map.of(
                        "type", "json_schema",
                        "name", "novelty_mission",
                        "strict", true,
                        "schema", schema)));
        try {
            return objectMapper.writeValueAsString(body);
        } catch (JacksonException exception) {
            throw new IllegalStateException("OpenAI request could not be serialized.", exception);
        }
    }

    private GeneratedMission parseGeneratedMission(String responseBody) {
        try {
            JsonNode root = objectMapper.readTree(responseBody);
            for (JsonNode output : root.path("output")) {
                for (JsonNode content : output.path("content")) {
                    if ("output_text".equals(content.path("type").stringValue())) {
                        return objectMapper.readValue(
                                content.path("text").stringValue(), GeneratedMission.class);
                    }
                }
            }
            throw new IllegalStateException("OpenAI response did not contain structured output text.");
        } catch (JacksonException exception) {
            throw new IllegalStateException("OpenAI structured output could not be parsed.", exception);
        }
    }
}
