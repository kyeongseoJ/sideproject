package com.novelty.user;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DuplicateKeyException;

import com.novelty.personality.ExecutionStyle;
import com.novelty.personality.IndoorOutdoor;
import com.novelty.personality.Interest;
import com.novelty.personality.NoveltyLevel;
import com.novelty.personality.PersonalityRepository;
import com.novelty.personality.PhysicalActivityLevel;
import com.novelty.personality.SocialLevel;

class UserServiceTest {

    private UserRepository userRepository;
    private NicknameBannedWords nicknameBannedWords;
    private SecureRandom secureRandom;
    private UserService userService;

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        nicknameBannedWords = mock(NicknameBannedWords.class);
        secureRandom = mock(SecureRandom.class);
        userService = new UserService(userRepository, nicknameBannedWords, secureRandom);
    }

    @Test
    void createsAnonymousUserWithHashedKeyAndExpectedNicknameFormat() throws Exception {
        prepareDeterministicRandom();
        when(userRepository.nextUserId()).thenReturn(7L);

        AnonymousUserResponse response = userService.createAnonymousUser();

        String expectedKey = Base64.getUrlEncoder().withoutPadding()
                .encodeToString(repeatedBytes((byte) 1));
        String expectedHash = HexFormat.of().formatHex(
                MessageDigest.getInstance("SHA-256")
                        .digest(expectedKey.getBytes(StandardCharsets.UTF_8)));

        assertEquals(expectedKey, response.userKey());
        assertEquals(7L, response.userId());
        assertEquals("노벨티07QK", response.nickname());
        assertFalse(response.personalityCompleted());
        assertFalse(response.toString().contains(expectedKey));
        assertTrue(response.toString().contains("<redacted>"));
        verify(userRepository).create(7L, expectedHash, "노벨티07QK", "노벨티07QK");
    }

    @Test
    void stopsAfterTwentyNicknameCollisions() {
        prepareDeterministicRandom();
        when(userRepository.nextUserId()).thenReturn(1L);
        doThrow(new DuplicateKeyException("collision"))
                .when(userRepository)
                .create(anyLong(), anyString(), anyString(), anyString());

        assertThrows(NicknameGenerationException.class, userService::createAnonymousUser);

        verify(userRepository, org.mockito.Mockito.times(20))
                .create(anyLong(), anyString(), anyString(), anyString());
    }

    @Test
    void returnsCurrentUserAndTouchesLastSeenTime() {
        String userKey = validUserKey();
        when(userRepository.findByUserKeyHash(anyString()))
                .thenReturn(Optional.of(new UserAccount(9L, "노벨티07QK", false)));

        UserProfileResponse response = userService.getCurrentUser(userKey);

        assertEquals("노벨티07QK", response.nickname());
        assertEquals(9L, response.userId());
        assertFalse(response.personalityCompleted());
        assertEquals(null, response.personality());
        verify(userRepository).touch(9L);
    }

    @Test
    void returnsStoredPersonalityInCurrentUserProfile() {
        PersonalityRepository personalityRepository = mock(PersonalityRepository.class);
        userService = new UserService(
                userRepository,
                nicknameBannedWords,
                personalityRepository,
                secureRandom);
        when(userRepository.findByUserKeyHash(anyString()))
                .thenReturn(Optional.of(new UserAccount(9L, "노벨티07QK", true)));
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
        when(personalityRepository.findCurrentProfile(9L)).thenReturn(Optional.of(personality));

        UserProfileResponse response = userService.getCurrentUser(validUserKey());

        assertTrue(response.personalityCompleted());
        assertEquals("QUIET_FOCUSER", response.personality().typeCode());
        assertEquals(IndoorOutdoor.INDOOR, response.personality().indoorOutdoor());
        verify(personalityRepository).findCurrentProfile(9L);
        verify(userRepository).touch(9L);
    }

    @Test
    void rejectsMissingOrMalformedUserKeyBeforeDatabaseLookup() {
        assertThrows(InvalidUserKeyException.class, () -> userService.getCurrentUser(null));
        assertThrows(InvalidUserKeyException.class, () -> userService.getCurrentUser("short-key"));

        verifyNoInteractions(userRepository);
    }

    @Test
    void rejectsUnknownUserKey() {
        when(userRepository.findByUserKeyHash(anyString())).thenReturn(Optional.empty());

        assertThrows(InvalidUserKeyException.class,
                () -> userService.getCurrentUser(validUserKey()));

        verify(userRepository, never()).touch(anyLong());
    }

    @Test
    void updatesValidNicknameUsingNormalizedDuplicateValue() {
        when(userRepository.findByUserKeyHash(anyString()))
                .thenReturn(Optional.of(new UserAccount(3L, "기존닉네임", false)));
        when(userRepository.containsActiveBannedWord("NOVELTY7")).thenReturn(false);
        when(userRepository.nicknameExists("NOVELTY7", 3L)).thenReturn(false);

        NicknameResponse response = userService.updateNickname(
                validUserKey(),
                new NicknameUpdateRequest("Novelty7"));

        assertEquals("Novelty7", response.nickname());
        verify(userRepository).updateNickname(3L, "Novelty7", "NOVELTY7");
    }

    @Test
    void rejectsInvalidNicknameCharactersAndLength() {
        when(userRepository.findByUserKeyHash(anyString()))
                .thenReturn(Optional.of(new UserAccount(3L, "기존닉네임", false)));

        assertThrows(InvalidNicknameException.class,
                () -> userService.updateNickname(validUserKey(), new NicknameUpdateRequest("공백 닉네임")));
        assertThrows(InvalidNicknameException.class,
                () -> userService.updateNickname(validUserKey(), new NicknameUpdateRequest("")));
        assertThrows(InvalidNicknameException.class,
                () -> userService.updateNickname(validUserKey(), null));
    }

    @Test
    void rejectsBannedNicknameWithoutExposingBannedWord() {
        when(userRepository.findByUserKeyHash(anyString()))
                .thenReturn(Optional.of(new UserAccount(3L, "기존닉네임", false)));
        when(nicknameBannedWords.contains("차단대상닉네임")).thenReturn(true);

        BannedNicknameException exception = assertThrows(
                BannedNicknameException.class,
                () -> userService.updateNickname(
                        validUserKey(),
                        new NicknameUpdateRequest("차단대상닉네임")));

        assertEquals("사용할 수 없는 닉네임입니다.", exception.getMessage());
        verify(userRepository, never()).nicknameExists(anyString(), anyLong());
        verify(userRepository, never()).containsActiveBannedWord(anyString());
    }

    @Test
    void fallsBackToDatabaseBannedWordsWhenFileDoesNotContainNickname() {
        when(userRepository.findByUserKeyHash(anyString()))
                .thenReturn(Optional.of(new UserAccount(3L, "기존닉네임", false)));
        when(userRepository.containsActiveBannedWord("DB차단대상")).thenReturn(true);

        assertThrows(BannedNicknameException.class,
                () -> userService.updateNickname(
                        validUserKey(),
                        new NicknameUpdateRequest("DB차단대상")));
    }

    @Test
    void rejectsDuplicateNickname() {
        when(userRepository.findByUserKeyHash(anyString()))
                .thenReturn(Optional.of(new UserAccount(3L, "기존닉네임", false)));
        when(userRepository.nicknameExists(eq("DUPLICATE1"), eq(3L))).thenReturn(true);

        assertThrows(DuplicateNicknameException.class,
                () -> userService.updateNickname(
                        validUserKey(),
                        new NicknameUpdateRequest("Duplicate1")));

        verify(userRepository, never()).updateNickname(anyLong(), anyString(), anyString());
    }

    @Test
    void convertsConcurrentNicknameCollisionToDomainError() {
        when(userRepository.findByUserKeyHash(anyString()))
                .thenReturn(Optional.of(new UserAccount(3L, "기존닉네임", false)));
        doThrow(new DuplicateKeyException("concurrent collision"))
                .when(userRepository)
                .updateNickname(3L, "Available1", "AVAILABLE1");

        assertThrows(DuplicateNicknameException.class,
                () -> userService.updateNickname(
                        validUserKey(),
                        new NicknameUpdateRequest("Available1")));
    }

    private void prepareDeterministicRandom() {
        doAnswer(invocation -> {
            byte[] bytes = invocation.getArgument(0);
            java.util.Arrays.fill(bytes, (byte) 1);
            return null;
        }).when(secureRandom).nextBytes(org.mockito.ArgumentMatchers.any(byte[].class));
        when(secureRandom.nextInt(100)).thenReturn(7);
        when(secureRandom.nextInt(26)).thenReturn(16, 10);
    }

    private byte[] repeatedBytes(byte value) {
        byte[] bytes = new byte[32];
        java.util.Arrays.fill(bytes, value);
        return bytes;
    }

    private String validUserKey() {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(repeatedBytes((byte) 2));
    }
}
