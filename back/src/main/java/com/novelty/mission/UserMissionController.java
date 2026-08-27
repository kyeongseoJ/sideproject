package com.novelty.mission;

import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import java.util.List;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;

@RestController
@RequestMapping("/api/user-missions")
@Tag(name = "사용자 미션", description = "오늘 추천 후보의 선택·취소·교체·완료 API")
public class UserMissionController {

    private final UserMissionService userMissionService;

    public UserMissionController(UserMissionService userMissionService) {
        this.userMissionService = userMissionService;
    }

    @GetMapping("/history")
    @Operation(summary = "완료 미션 이력 조회", description = "사용자가 완료한 미션을 최신순으로 조회합니다.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "완료 미션 이력 조회 성공"),
            @ApiResponse(responseCode = "400", description = "조회 개수 형식 오류"),
            @ApiResponse(responseCode = "401", description = "사용자 인증 실패")
    })
    public List<UserMissionResponse> history(
            @RequestHeader(value = "X-User-Key", required = false) String userKey,
            @RequestParam(defaultValue = "50") int limit) {
        return userMissionService.getCompletedHistory(userKey, limit);
    }

    @PostMapping("/{userMissionId}/select")
    @Operation(summary = "추천 후보 선택", description = "오늘 후보를 수행 중 상태로 선택합니다.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "선택 성공"),
            @ApiResponse(responseCode = "404", description = "소유한 사용자 미션이 아님"),
            @ApiResponse(responseCode = "409", description = "하루 한도 또는 상태 충돌")
    })
    public UserMissionActionResponse select(
            @RequestHeader(value = "X-User-Key", required = false) String userKey,
            @Parameter(description = "사용자 미션 ID", required = true)
            @PathVariable long userMissionId) {
        return userMissionService.select(userKey, userMissionId);
    }

    @PostMapping("/{userMissionId}/cancel")
    @Operation(summary = "수행 중 미션 취소")
    public UserMissionActionResponse cancel(
            @RequestHeader(value = "X-User-Key", required = false) String userKey,
            @PathVariable long userMissionId) {
        return userMissionService.cancel(userKey, userMissionId);
    }

    @PostMapping("/{userMissionId}/replace")
    @Operation(summary = "수행 중 미션 교체", description = "오늘의 다른 추천 후보로 슬롯을 원자적으로 이전합니다.")
    public UserMissionActionResponse replace(
            @RequestHeader(value = "X-User-Key", required = false) String userKey,
            @PathVariable long userMissionId,
            @RequestBody ReplacementMissionRequest request) {
        return userMissionService.replace(userKey, userMissionId, request);
    }

    @PostMapping("/{userMissionId}/complete")
    @Operation(summary = "수행 중 미션 완료", description = "같은 완료 요청은 멱등하게 기존 결과를 반환합니다.")
    public UserMissionActionResponse complete(
            @RequestHeader(value = "X-User-Key", required = false) String userKey,
            @PathVariable long userMissionId) {
        return userMissionService.complete(userKey, userMissionId);
    }
}
