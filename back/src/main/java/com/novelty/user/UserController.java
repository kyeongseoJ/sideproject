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

    @PostMapping("/register")
    @Operation(summary = "회원가입", description = "아이디와 비밀번호로 계정을 만들고 초기 랜덤 닉네임과 사용자 키를 반환합니다.")
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "가입 성공"),
            @ApiResponse(responseCode = "400", description = "아이디 또는 비밀번호 정책 위반"),
            @ApiResponse(responseCode = "409", description = "중복 아이디")
    })
    public ResponseEntity<AccountSessionResponse> register(
            @RequestBody AccountRegistrationRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(userService.register(request));
    }

    @PostMapping("/login")
    @Operation(summary = "로그인", description = "아이디와 비밀번호를 확인하고 이후 API에 사용할 사용자 키를 반환합니다.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "로그인 성공"),
            @ApiResponse(responseCode = "401", description = "아이디 또는 비밀번호 불일치")
    })
    public AccountSessionResponse login(@RequestBody AccountLoginRequest request) {
        return userService.login(request);
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
            @Parameter(description = "회원가입 또는 로그인 응답에서 받은 사용자 키", required = true)
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
            @Parameter(description = "회원가입 또는 로그인 응답에서 받은 사용자 키", required = true)
            @RequestHeader(value = "X-User-Key", required = false) String userKey,
            @RequestBody NicknameUpdateRequest request) {
        return userService.updateNickname(userKey, request);
    }
}
