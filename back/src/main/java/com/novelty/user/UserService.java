package com.novelty.user;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.text.Normalizer;
import java.util.Base64;
import java.util.Locale;
import java.util.regex.Pattern;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.novelty.personality.PersonalityRepository;

@Service
public class UserService {

    private static final int USER_KEY_BYTES = 32;
    private static final int MAX_NICKNAME_GENERATION_ATTEMPTS = 20;
    private static final String INITIAL_NICKNAME_PREFIX = "노벨티";
    private static final Pattern USER_KEY_PATTERN = Pattern.compile("^[A-Za-z0-9_-]{43}$");
    private static final Pattern NICKNAME_PATTERN = Pattern.compile("^[가-힣A-Za-z0-9]{1,12}$");

    private final UserRepository userRepository;
    private final NicknameBannedWords nicknameBannedWords;
    private final PersonalityRepository personalityRepository;
    private final SecureRandom secureRandom;

    @Autowired
    public UserService(
            UserRepository userRepository,
            NicknameBannedWords nicknameBannedWords,
            PersonalityRepository personalityRepository) {
        this(userRepository, nicknameBannedWords, personalityRepository, new SecureRandom());
    }

    UserService(
            UserRepository userRepository,
            NicknameBannedWords nicknameBannedWords,
            SecureRandom secureRandom) {
        this(userRepository, nicknameBannedWords, null, secureRandom);
    }

    UserService(
            UserRepository userRepository,
            NicknameBannedWords nicknameBannedWords,
            PersonalityRepository personalityRepository,
            SecureRandom secureRandom) {
        this.userRepository = userRepository;
        this.nicknameBannedWords = nicknameBannedWords;
        this.personalityRepository = personalityRepository;
        this.secureRandom = secureRandom;
    }

    @Transactional
    public AnonymousUserResponse createAnonymousUser() {
        for (int attempt = 0; attempt < MAX_NICKNAME_GENERATION_ATTEMPTS; attempt++) {
            String userKey = generateUserKey();
            String nickname = generateInitialNickname();
            try {
                long userId = userRepository.nextUserId();
                userRepository.create(
                        userId,
                        hashUserKey(userKey),
                        nickname,
                        normalizeNickname(nickname));
                return new AnonymousUserResponse(userId, userKey, nickname, false);
            } catch (DuplicateKeyException exception) {
                // A concurrent nickname or practically impossible user-key collision is retried.
            }
        }
        throw new NicknameGenerationException();
    }

    @Transactional
    public UserProfileResponse getCurrentUser(String userKey) {
        UserAccount user = authenticate(userKey);
        UserPersonalityResponse personality = personalityRepository == null
                ? null
                : personalityRepository.findCurrentProfile(user.userId()).orElse(null);
        userRepository.touch(user.userId());
        return UserProfileResponse.from(user, personality);
    }

    @Transactional
    public NicknameResponse updateNickname(String userKey, NicknameUpdateRequest request) {
        UserAccount user = authenticate(userKey);
        String nickname = validateAndNormalizeDisplayNickname(request);
        String normalizedNickname = normalizeNickname(nickname);

        if (nicknameBannedWords.contains(normalizedNickname)
                || userRepository.containsActiveBannedWord(normalizedNickname)) {
            throw new BannedNicknameException();
        }
        if (userRepository.nicknameExists(normalizedNickname, user.userId())) {
            throw new DuplicateNicknameException();
        }

        try {
            userRepository.updateNickname(user.userId(), nickname, normalizedNickname);
        } catch (DuplicateKeyException exception) {
            throw new DuplicateNicknameException();
        }
        return new NicknameResponse(nickname);
    }

    public long requireUserId(String userKey) {
        try {
            return authenticate(userKey).userId();
        } catch (InvalidUserKeyException exception) {
            throw new UserAuthenticationException();
        }
    }

    private UserAccount authenticate(String userKey) {
        if (userKey == null || !USER_KEY_PATTERN.matcher(userKey).matches()) {
            throw new InvalidUserKeyException();
        }
        return userRepository.findByUserKeyHash(hashUserKey(userKey))
                .orElseThrow(InvalidUserKeyException::new);
    }

    private String validateAndNormalizeDisplayNickname(NicknameUpdateRequest request) {
        if (request == null
                || request.nickname() == null
                || !NICKNAME_PATTERN.matcher(request.nickname()).matches()) {
            throw new InvalidNicknameException();
        }
        String nickname = Normalizer.normalize(request.nickname(), Normalizer.Form.NFC);
        if (!NICKNAME_PATTERN.matcher(nickname).matches()) {
            throw new InvalidNicknameException();
        }
        return nickname;
    }

    private String generateUserKey() {
        byte[] bytes = new byte[USER_KEY_BYTES];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String generateInitialNickname() {
        int number = secureRandom.nextInt(100);
        char firstLetter = (char) ('A' + secureRandom.nextInt(26));
        char secondLetter = (char) ('A' + secureRandom.nextInt(26));
        return "%s%02d%c%c".formatted(
                INITIAL_NICKNAME_PREFIX,
                number,
                firstLetter,
                secondLetter);
    }

    private String normalizeNickname(String nickname) {
        return Normalizer.normalize(nickname, Normalizer.Form.NFC).toUpperCase(Locale.ROOT);
    }

    private String hashUserKey(String userKey) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(userKey.getBytes(StandardCharsets.UTF_8));
            return java.util.HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is not available.", exception);
        }
    }
}
