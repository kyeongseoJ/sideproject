package com.novelty.survey;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;

@RestController
@RequestMapping("/api/surveys")
@CrossOrigin(originPatterns = {"http://localhost:*", "http://127.0.0.1:*"})
@Tag(name = "Survey", description = "초기 행동 선택지 설문 API")
public class SurveyController {

    private final SurveyService surveyService;

    public SurveyController(SurveyService surveyService) {
        this.surveyService = surveyService;
    }

    @PostMapping
    @Operation(summary = "설문 응답 저장", description = "5개 행동 선택 결과를 Oracle에 저장합니다.")
    @ApiResponses({
            @ApiResponse(
                    responseCode = "201",
                    description = "저장 성공",
                    content = @Content(schema = @Schema(implementation = SurveyResponse.class))),
            @ApiResponse(
                    responseCode = "400",
                    description = "입력값 검증 실패",
                    content = @Content(schema = @Schema(implementation = SurveyErrorResponse.class))),
            @ApiResponse(
                    responseCode = "500",
                    description = "Database 저장 실패",
                    content = @Content(schema = @Schema(implementation = SurveyErrorResponse.class)))
    })
    public ResponseEntity<SurveyResponse> create(@RequestBody SurveyRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(surveyService.save(request));
    }
}
