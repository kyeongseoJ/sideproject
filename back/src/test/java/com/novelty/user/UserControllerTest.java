package com.novelty.user;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.OffsetDateTime;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import com.novelty.personality.ExecutionStyle;
import com.novelty.personality.IndoorOutdoor;
import com.novelty.personality.Interest;
import com.novelty.personality.NoveltyLevel;
import com.novelty.personality.PhysicalActivityLevel;
import com.novelty.personality.SocialLevel;

class UserControllerTest {

    private static final String USER_KEY = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

    private UserService userService;
    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        userService = mock(UserService.class);
        mockMvc = MockMvcBuilders.standaloneSetup(new UserController(userService))
                .setControllerAdvice(new UserExceptionHandler())
                .build();
    }

    @Test
    void createsAnonymousUser() throws Exception {
        when(userService.createAnonymousUser())
                .thenReturn(new AnonymousUserResponse(7L, USER_KEY, "노벨티07QK", false));

        mockMvc.perform(post("/api/users/anonymous"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.userId").value(7))
                .andExpect(jsonPath("$.userKey").value(USER_KEY))
                .andExpect(jsonPath("$.nickname").value("노벨티07QK"))
                .andExpect(jsonPath("$.personalityCompleted").value(false));
    }

    @Test
    void registersAccount() throws Exception {
        when(userService.register(any(AccountRegistrationRequest.class)))
                .thenReturn(new AccountSessionResponse(7L, USER_KEY, "노벨티07QK", false));

        mockMvc.perform(post("/api/users/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"loginId":"tester1","password":"Password1"}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.userKey").value(USER_KEY))
                .andExpect(jsonPath("$.nickname").value("노벨티07QK"));
    }

    @Test
    void logsIn() throws Exception {
        when(userService.login(any(AccountLoginRequest.class)))
                .thenReturn(new AccountSessionResponse(7L, USER_KEY, "노벨티07QK", true));

        mockMvc.perform(post("/api/users/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"loginId":"tester1","password":"Password1"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.personalityCompleted").value(true));
    }

    @Test
    void returnsCurrentUser() throws Exception {
        when(userService.getCurrentUser(USER_KEY))
                .thenReturn(new UserProfileResponse(7L, "노벨티07QK", false, null));

        mockMvc.perform(get("/api/users/me").header("X-User-Key", USER_KEY))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(7))
                .andExpect(jsonPath("$.nickname").value("노벨티07QK"))
                .andExpect(jsonPath("$.personalityCompleted").value(false))
                .andExpect(jsonPath("$.personality").isEmpty());
    }

    @Test
    void returnsCurrentUserWithStoredPersonalityProfile() throws Exception {
        UserPersonalityResponse personality = new UserPersonalityResponse(
                "QUIET_FOCUSER",
                "고요한 몰입가",
                "익숙하고 조용한 공간에서 혼자 집중할 때 편안해요.",
                IndoorOutdoor.INDOOR,
                -1,
                SocialLevel.LOW,
                -1,
                PhysicalActivityLevel.LOW,
                0,
                NoveltyLevel.MEDIUM,
                1,
                ExecutionStyle.PLANNED,
                List.of(Interest.CREATIVE),
                "PERSONALITY_V2",
                OffsetDateTime.parse("2026-08-19T17:15:00+09:00"));
        when(userService.getCurrentUser(USER_KEY))
                .thenReturn(new UserProfileResponse(7L, "노벨티07QK", true, personality));

        mockMvc.perform(get("/api/users/me").header("X-User-Key", USER_KEY))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.personalityCompleted").value(true))
                .andExpect(jsonPath("$.personality.typeCode").value("QUIET_FOCUSER"))
                .andExpect(jsonPath("$.personality.indoorOutdoor").value("INDOOR"))
                .andExpect(jsonPath("$.personality.physicalActivityScore").value(0))
                .andExpect(jsonPath("$.personality.interests[0]").value("CREATIVE"))
                .andExpect(jsonPath("$.personality.analysisVersion").value("PERSONALITY_V2"));
    }

    @Test
    void updatesNickname() throws Exception {
        when(userService.updateNickname(anyString(), any(NicknameUpdateRequest.class)))
                .thenReturn(new NicknameResponse("새닉네임1"));

        mockMvc.perform(patch("/api/users/me/nickname")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"nickname":"새닉네임1"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nickname").value("새닉네임1"));
    }

    @Test
    void returnsUnauthorizedForInvalidUserKey() throws Exception {
        when(userService.getCurrentUser(any()))
                .thenThrow(new InvalidUserKeyException());

        mockMvc.perform(get("/api/users/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_USER_KEY"));
    }

    @Test
    void returnsBadRequestForInvalidNickname() throws Exception {
        when(userService.updateNickname(anyString(), any(NicknameUpdateRequest.class)))
                .thenThrow(new InvalidNicknameException());

        mockMvc.perform(patch("/api/users/me/nickname")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"nickname":"invalid nickname"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_NICKNAME"));
    }

    @Test
    void returnsConflictForDuplicateNickname() throws Exception {
        when(userService.updateNickname(anyString(), any(NicknameUpdateRequest.class)))
                .thenThrow(new DuplicateNicknameException());

        mockMvc.perform(patch("/api/users/me/nickname")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"nickname":"Duplicate1"}
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("DUPLICATE_NICKNAME"));
    }

    @Test
    void returnsBadRequestForMalformedJson() throws Exception {
        mockMvc.perform(patch("/api/users/me/nickname")
                        .header("X-User-Key", USER_KEY)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
    }

    @Test
    void allowsLocalFrontendOrigin() throws Exception {
        when(userService.createAnonymousUser())
                .thenReturn(new AnonymousUserResponse(7L, USER_KEY, "노벨티07QK", false));

        mockMvc.perform(post("/api/users/anonymous")
                        .header(HttpHeaders.ORIGIN, "http://localhost:3000"))
                .andExpect(status().isCreated())
                .andExpect(header().string(
                        HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN,
                        "http://localhost:3000"));
    }
}
