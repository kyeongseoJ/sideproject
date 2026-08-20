package com.novelty.mission;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.PutMapping;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;

@RestController
@RequestMapping("/api/missions")
@CrossOrigin(originPatterns = {"http://localhost:*", "http://127.0.0.1:*"})
@Tag(name = "Mission", description = "성향 벡터 기반 미션 추천과 수행 상태 API")
public class MissionController {

    private final MissionService missionService;

    public MissionController(MissionService missionService) {
        this.missionService = missionService;
    }

    @GetMapping("/settings")
    @Operation(summary = "미션 설정 조회", description = "사용 가능 시간과 하루 수행 한도를 조회합니다.")
    public MissionSettingsResponse getSettings(
            @Parameter(description = "익명 사용자 키", required = true)
            @RequestHeader(value = "X-User-Key", required = false) String userKey) {
        return missionService.getSettings(userKey);
    }

    @PutMapping("/settings")
    @Operation(summary = "미션 설정 저장", description = "사용 가능 시간과 하루 수행 한도(1~3)를 저장합니다.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "저장 성공"),
            @ApiResponse(responseCode = "400", description = "잘못된 시간 또는 하루 한도"),
            @ApiResponse(responseCode = "401", description = "사용자 키 오류")
    })
    public MissionSettingsResponse saveSettings(
            @Parameter(description = "익명 사용자 키", required = true)
            @RequestHeader(value = "X-User-Key", required = false) String userKey,
            @RequestBody MissionSettingsRequest request) {
        return missionService.saveSettings(userKey, request);
    }

    @GetMapping("/today")
    @Operation(summary = "오늘의 미션 조회", description = "서울 날짜 기준 설정, 수행 중 미션과 기존 후보를 조회합니다.")
    public MissionTodayResponse getToday(
            @Parameter(description = "익명 사용자 키", required = true)
            @RequestHeader(value = "X-User-Key", required = false) String userKey) {
        return missionService.getToday(userKey);
    }

    @PostMapping("/today/recommendations")
    @Operation(
            summary = "오늘의 추천 후보 생성",
            description = "오늘 후보를 최초 생성하며 이미 생성된 경우 같은 후보를 재사용합니다.")
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "오늘 후보 최초 생성"),
            @ApiResponse(responseCode = "200", description = "기존 오늘 후보 재사용"),
            @ApiResponse(responseCode = "401", description = "사용자 키 오류"),
            @ApiResponse(responseCode = "409", description = "성향·설정 필요 또는 추천 후보 없음")
    })
    public ResponseEntity<MissionTodayResponse> recommendToday(
            @Parameter(description = "익명 사용자 키", required = true)
            @RequestHeader(value = "X-User-Key", required = false) String userKey) {
        MissionRecommendationBatchResult result = missionService.recommendToday(userKey);
        return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK)
                .body(result.response());
    }

    @PostMapping("/random")
    @Operation(
            summary = "랜덤 미션 추천",
            description = "성향 벡터에서 거리가 먼 미션을 우선 선별하고 최근 이력 정책을 적용합니다.")
    @ApiResponses({
            @ApiResponse(
                    responseCode = "200",
                    description = "추천 성공",
                    content = @Content(schema = @Schema(implementation = MissionResponse.class))),
            @ApiResponse(
                    responseCode = "400",
                    description = "시간 선택 누락 또는 잘못된 요청",
                    content = @Content(schema = @Schema(implementation = MissionErrorResponse.class))),
            @ApiResponse(responseCode = "401", description = "사용자 키 오류"),
            @ApiResponse(responseCode = "409", description = "성향 분석 필요 또는 추천 가능 미션 없음")
    })
    public MissionResponse recommend(
            @Parameter(description = "익명 사용자 키", required = true)
            @RequestHeader(value = "X-User-Key", required = false) String userKey,
            @RequestBody MissionRecommendationRequest request) {
        return missionService.recommend(userKey, request);
    }

    @PatchMapping("/{missionId}/status")
    @Operation(
            summary = "미션 상태 변경",
            description = "SHOWN→SELECTED, SELECTED→CANCELLED/COMPLETED 전이만 허용합니다. "
                    + "완료 5회마다 성향 벡터 갱신과 LLM 미션 생성을 시도합니다.")
    public MissionStatusResponse changeStatus(
            @Parameter(description = "익명 사용자 키", required = true)
            @RequestHeader(value = "X-User-Key", required = false) String userKey,
            @PathVariable long missionId,
            @RequestBody MissionStatusRequest request) {
        return missionService.changeStatus(userKey, missionId, request);
    }
}
