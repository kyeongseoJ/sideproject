package com.novelty.mission;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;

@RestController
@RequestMapping("/api/missions")
@Tag(name = "미션", description = "성향 기반 미션 추천과 오늘의 미션 조회 API")
public class MissionController {

    private final MissionService missionService;

    public MissionController(MissionService missionService) {
        this.missionService = missionService;
    }

    @GetMapping("/today")
    @Operation(
            summary = "오늘의 미션 상태 조회",
            description = "오늘 선택한 미션과 추천 후보를 조회합니다.")
    @ApiResponse(responseCode = "200", description = "오늘의 미션 상태 조회 성공")
    public MissionTodayResponse getToday(
            @Parameter(description = "사용자 키", required = true)
            @RequestHeader(value = "X-User-Key", required = false) String userKey) {
        return missionService.getToday(userKey);
    }

    @PostMapping("/today/recommendations")
    @Operation(
            summary = "오늘의 미션 후보 생성",
            description = "하루 한 개의 미션을 선택할 수 있도록 최대 다섯 개의 후보를 생성합니다.")
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "미션 후보 생성 성공"),
            @ApiResponse(responseCode = "200", description = "기존 미션 후보 반환"),
            @ApiResponse(responseCode = "401", description = "사용자 인증 실패"),
            @ApiResponse(responseCode = "409", description = "성향 분석 또는 미션 후보를 사용할 수 없음")
    })
    public ResponseEntity<MissionTodayResponse> recommendToday(
            @Parameter(description = "사용자 키", required = true)
            @RequestHeader(value = "X-User-Key", required = false) String userKey) {
        MissionRecommendationBatchResult result = missionService.recommendToday(userKey);
        return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK)
                .body(result.response());
    }
}
