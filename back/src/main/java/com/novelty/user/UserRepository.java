package com.novelty.user;

import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class UserRepository {

    private static final String NEXT_USER_ID_SQL =
            "SELECT nextval('novelty_user_seq')";

    private static final String INSERT_USER_SQL = """
            INSERT INTO NOVELTY_USER (
                USER_ID, USER_KEY_HASH, NICKNAME, NICKNAME_NORMALIZED
            ) VALUES (?, ?, ?, ?)
            """;

    private static final String INSERT_ACCOUNT_SQL = """
            INSERT INTO NOVELTY_USER (
                USER_ID, USER_KEY_HASH, LOGIN_ID_NORMALIZED, PASSWORD_HASH,
                NICKNAME, NICKNAME_NORMALIZED
            ) VALUES (?, ?, ?, ?, ?, ?)
            """;

    private static final String FIND_USER_SQL = """
            SELECT
                u.USER_ID,
                u.NICKNAME,
                CASE WHEN p.USER_ID IS NULL THEN 0 ELSE 1 END AS PERSONALITY_COMPLETED
            FROM NOVELTY_USER u
            LEFT JOIN USER_PERSONALITY_PROFILE p ON p.USER_ID = u.USER_ID
            WHERE u.USER_KEY_HASH = ?
            """;

    private static final String FIND_CREDENTIALS_SQL = """
            SELECT
                u.USER_ID,
                u.PASSWORD_HASH,
                u.NICKNAME,
                CASE WHEN p.USER_ID IS NULL THEN 0 ELSE 1 END AS PERSONALITY_COMPLETED
            FROM NOVELTY_USER u
            LEFT JOIN USER_PERSONALITY_PROFILE p ON p.USER_ID = u.USER_ID
            WHERE u.LOGIN_ID_NORMALIZED = ?
            """;

    private static final String TOUCH_USER_SQL = """
            UPDATE NOVELTY_USER
               SET LAST_SEEN_AT = CURRENT_TIMESTAMP
             WHERE USER_ID = ?
            """;

    private static final String FIND_DUPLICATE_NICKNAME_SQL = """
            SELECT COUNT(*)
            FROM NOVELTY_USER
            WHERE NICKNAME_NORMALIZED = ?
              AND USER_ID <> ?
            """;

    private static final String FIND_BANNED_NICKNAME_SQL = """
            SELECT COUNT(*)
            FROM NICKNAME_BANNED_WORD
            WHERE ACTIVE = 'Y'
              AND strpos(?, WORD_NORMALIZED) > 0
            """;

    private static final String UPDATE_NICKNAME_SQL = """
            UPDATE NOVELTY_USER
               SET NICKNAME = ?,
                   NICKNAME_NORMALIZED = ?,
                   UPDATED_AT = CURRENT_TIMESTAMP,
                   LAST_SEEN_AT = CURRENT_TIMESTAMP
             WHERE USER_ID = ?
            """;

    private final JdbcTemplate jdbcTemplate;

    public UserRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public long nextUserId() {
        Long userId = jdbcTemplate.queryForObject(NEXT_USER_ID_SQL, Long.class);
        if (userId == null) {
            throw new IllegalStateException("PostgreSQL did not return a user ID.");
        }
        return userId;
    }

    public void create(long userId, String userKeyHash, String nickname, String normalizedNickname) {
        jdbcTemplate.update(
                INSERT_USER_SQL,
                userId,
                userKeyHash,
                nickname,
                normalizedNickname);
    }

    public void createAccount(
            long userId,
            String userKeyHash,
            String normalizedLoginId,
            String passwordHash,
            String nickname,
            String normalizedNickname) {
        jdbcTemplate.update(
                INSERT_ACCOUNT_SQL,
                userId,
                userKeyHash,
                normalizedLoginId,
                passwordHash,
                nickname,
                normalizedNickname);
    }

    public Optional<UserAccount> findByUserKeyHash(String userKeyHash) {
        List<UserAccount> users = jdbcTemplate.query(
                FIND_USER_SQL,
                (resultSet, rowNumber) -> new UserAccount(
                        resultSet.getLong("USER_ID"),
                        resultSet.getString("NICKNAME"),
                        resultSet.getInt("PERSONALITY_COMPLETED") == 1),
                userKeyHash);
        return users.stream().findFirst();
    }

    public Optional<UserCredentials> findCredentials(String normalizedLoginId) {
        List<UserCredentials> users = jdbcTemplate.query(
                FIND_CREDENTIALS_SQL,
                (resultSet, rowNumber) -> new UserCredentials(
                        resultSet.getLong("USER_ID"),
                        resultSet.getString("PASSWORD_HASH"),
                        resultSet.getString("NICKNAME"),
                        resultSet.getInt("PERSONALITY_COMPLETED") == 1),
                normalizedLoginId);
        return users.stream().findFirst();
    }

    public boolean loginIdExists(String normalizedLoginId) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM NOVELTY_USER WHERE LOGIN_ID_NORMALIZED = ?",
                Integer.class,
                normalizedLoginId);
        return count != null && count > 0;
    }

    public void rotateUserKey(long userId, String userKeyHash) {
        jdbcTemplate.update(
                """
                UPDATE NOVELTY_USER
                   SET USER_KEY_HASH = ?, UPDATED_AT = CURRENT_TIMESTAMP,
                       LAST_SEEN_AT = CURRENT_TIMESTAMP
                 WHERE USER_ID = ?
                """,
                userKeyHash,
                userId);
    }

    public void touch(long userId) {
        jdbcTemplate.update(TOUCH_USER_SQL, userId);
    }

    public boolean nicknameExists(String normalizedNickname, long excludedUserId) {
        Integer count = jdbcTemplate.queryForObject(
                FIND_DUPLICATE_NICKNAME_SQL,
                Integer.class,
                normalizedNickname,
                excludedUserId);
        return count != null && count > 0;
    }

    public boolean containsActiveBannedWord(String normalizedNickname) {
        Integer count = jdbcTemplate.queryForObject(
                FIND_BANNED_NICKNAME_SQL,
                Integer.class,
                normalizedNickname);
        return count != null && count > 0;
    }

    public void updateNickname(long userId, String nickname, String normalizedNickname) {
        jdbcTemplate.update(UPDATE_NICKNAME_SQL, nickname, normalizedNickname, userId);
    }
}
