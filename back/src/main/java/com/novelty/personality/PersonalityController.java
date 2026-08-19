package com.novelty.personality;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;

@RestController
@RequestMapping("/api/personality-analyses")
@CrossOrigin(originPatterns = {"http://localhost:*", "http://127.0.0.1:*"})
@Tag(name = "Personality", description = "최초 성향 분석과 재분석 API")
public class PersonalityController {

    private final PersonalityService personalityService;

    public PersonalityController(PersonalityService personalityService) {
        this.personalityService = personalityService;
    }

    @PostMapping
    @Operation(
            summary = "성향 분석 저장",
            description = "여섯 문항을 분석하고 원본 답변과 현재 성향 프로필을 원자적으로 저장합니다. "
                    + "동일한 submissionKey 재시도는 기존 분석을 반환합니다.")
    @ApiResponses({
            @ApiResponse(
                    responseCode = "201",
                    description = "새 분석 저장 성공",
                    content = @Content(schema = @Schema(implementation = PersonalityAnalysisResponse.class))),
            @ApiResponse(
                    responseCode = "200",
                    description = "동일 제출 재시도 성공",
                    content = @Content(schema = @Schema(implementation = PersonalityAnalysisResponse.class))),
            @ApiResponse(
                    responseCode = "400",
                    description = "답변 또는 제출 식별자 오류",
                    content = @Content(schema = @Schema(implementation = PersonalityErrorResponse.class))),
            @ApiResponse(
                    responseCode = "401",
                    description = "사용자 키 오류",
                    content = @Content(schema = @Schema(implementation = PersonalityErrorResponse.class))),
            @ApiResponse(
                    responseCode = "409",
                    description = "분석 상태 또는 제출 식별자 충돌",
                    content = @Content(schema = @Schema(implementation = PersonalityErrorResponse.class))),
            @ApiResponse(
                    responseCode = "500",
                    description = "Database 저장 실패",
                    content = @Content(schema = @Schema(implementation = PersonalityErrorResponse.class)))
    })
    public ResponseEntity<PersonalityAnalysisResponse> analyze(
            @Parameter(description = "익명 사용자 생성 응답에서 받은 사용자 키", required = true)
            @RequestHeader(value = "X-User-Key", required = false) String userKey,
            @RequestBody PersonalityAnalysisRequest request) {
        PersonalitySubmissionResult result = personalityService.analyze(userKey, request);
        HttpStatus status = result.created() ? HttpStatus.CREATED : HttpStatus.OK;
        return ResponseEntity.status(status).body(result.response());
    }
}
