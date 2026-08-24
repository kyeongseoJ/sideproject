package com.novelty.world;

import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;

@RestController
@RequestMapping("/api/world")
@CrossOrigin(originPatterns = {"http://localhost:*", "http://127.0.0.1:*"})
@Tag(name = "World", description = "사용자별 3D World Object 성장 상태 API")
public class WorldController {

    private final WorldProgressService worldProgressService;

    public WorldController(WorldProgressService worldProgressService) {
        this.worldProgressService = worldProgressService;
    }

    @GetMapping
    @Operation(summary = "World Snapshot 조회", description = "활성 Category Object 8개의 현재 EXP와 Level을 조회합니다.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "조회 성공"),
            @ApiResponse(responseCode = "401", description = "사용자 키가 올바르지 않음"),
            @ApiResponse(responseCode = "500", description = "World 처리 실패")
    })
    public WorldSnapshotResponse getWorld(
            @RequestHeader(value = "X-User-Key", required = false) String userKey) {
        return worldProgressService.getSnapshot(userKey);
    }
}
