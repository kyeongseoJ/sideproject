package com.novelty.user;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
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
@RequestMapping("/api/users")
@CrossOrigin(originPatterns = {"http://localhost:*", "http://127.0.0.1:*"})
@Tag(name = "User", description = "회원가입 없는 익명 사용자와 닉네임 API")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping("/anonymous")
    @Operation(
            summary = "익명 사용자 생성",
            description = "사용자 키와 중복되지 않는 초기 랜덤 닉네임을 생성합니다. "
                    + "사용자 키 원문은 이 응답에서만 전달됩니다.")
    @ApiResponses({
            @ApiResponse(
                    responseCode = "201",
                    description = "생성 성공",
                    content = @Content(schema = @Schema(implementation = AnonymousUserResponse.class))),
            @ApiResponse(
                    responseCode = "500",
                    description = "사용자 또는 닉네임 생성 실패",
                    content = @Content(schema = @Schema(implementation = UserErrorResponse.class)))
    })
    public ResponseEntity<AnonymousUserResponse> createAnonymousUser() {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(userService.createAnonymousUser());
    }

    @GetMapping("/me")
    @Operation(summary = "현재 사용자 조회", description = "캐시된 사용자 키로 현재 프로필을 조회합니다.")
    @ApiResponses({
            @ApiResponse(
                    responseCode = "200",
                    description = "조회 성공",
                    content = @Content(schema = @Schema(implementation = UserProfileResponse.class))),
            @ApiResponse(
                    responseCode = "401",
                    description = "사용자 키가 없거나 유효하지 않음",
                    content = @Content(schema = @Schema(implementation = UserErrorResponse.class)))
    })
    public UserProfileResponse getCurrentUser(
            @Parameter(description = "익명 사용자 생성 응답에서 받은 사용자 키", required = true)
            @RequestHeader(value = "X-User-Key", required = false) String userKey) {
        return userService.getCurrentUser(userKey);
    }

    @PatchMapping("/me/nickname")
    @Operation(summary = "닉네임 변경", description = "닉네임 정책과 중복·금칙어 여부를 검증한 후 변경합니다.")
    @ApiResponses({
            @ApiResponse(
                    responseCode = "200",
                    description = "변경 성공",
                    content = @Content(schema = @Schema(implementation = NicknameResponse.class))),
            @ApiResponse(
                    responseCode = "400",
                    description = "닉네임 형식 또는 금칙어 검증 실패",
                    content = @Content(schema = @Schema(implementation = UserErrorResponse.class))),
            @ApiResponse(
                    responseCode = "401",
                    description = "사용자 키가 없거나 유효하지 않음",
                    content = @Content(schema = @Schema(implementation = UserErrorResponse.class))),
            @ApiResponse(
                    responseCode = "409",
                    description = "중복 닉네임",
                    content = @Content(schema = @Schema(implementation = UserErrorResponse.class)))
    })
    public NicknameResponse updateNickname(
            @Parameter(description = "익명 사용자 생성 응답에서 받은 사용자 키", required = true)
            @RequestHeader(value = "X-User-Key", required = false) String userKey,
            @RequestBody NicknameUpdateRequest request) {
        return userService.updateNickname(userKey, request);
    }
}
