package com.novelty.mission;

import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
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
@CrossOrigin(originPatterns = {"http://localhost:*", "http://127.0.0.1:*"})
@Tag(name = "Mission", description = "성향 벡터 기반 미션 추천과 수행 상태 API")
public class MissionSummaryController {

    private final UserMissionService userMissionService;

    public MissionSummaryController(UserMissionService userMissionService) {
        this.userMissionService = userMissionService;
    }

    @GetMapping("/summary")
    @Operation(
            summary = "미션 완료 요약 조회",
            description = "전체 완료 수, 마지막 성향 반영 경계와 카테고리별 완료 통계를 조회합니다.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "조회 성공"),
            @ApiResponse(responseCode = "401", description = "사용자 키 오류"),
            @ApiResponse(responseCode = "409", description = "성향 분석 필요")
    })
    public MissionSummaryResponse getSummary(
            @Parameter(description = "익명 사용자 키", required = true)
            @RequestHeader(value = "X-User-Key", required = false) String userKey) {
        return userMissionService.getSummary(userKey);
    }
}
