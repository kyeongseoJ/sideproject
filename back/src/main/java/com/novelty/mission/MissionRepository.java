package com.novelty.mission;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.OffsetDateTime;
import java.util.HexFormat;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.Arrays;
import java.util.stream.Collectors;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class MissionRepository {

    private static final String MISSION_COLUMNS = """
            MISSION_ID, TITLE, DESCRIPTION, CATEGORY, DIFFICULTY,
            ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL,
            ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL,
            UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS,
            ENABLED, SOURCE_TYPE
            """;

    private final JdbcTemplate jdbcTemplate;

    public MissionRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Optional<UserMissionVector> findUserVector(long userId) {
        List<UserMissionVector> profiles = jdbcTemplate.query("""
                SELECT ACTIVITY_SCORE, SOCIAL_SCORE, PHYSICAL_ACTIVITY_SCORE,
                       NOVELTY_SCORE, COMPLETED_MISSION_COUNT
                  FROM USER_PERSONALITY_PROFILE
                 WHERE USER_ID = ?
                """, (resultSet, rowNumber) -> new UserMissionVector(
                        resultSet.getInt("ACTIVITY_SCORE"),
                        resultSet.getInt("SOCIAL_SCORE"),
                        resultSet.getInt("PHYSICAL_ACTIVITY_SCORE"),
                        resultSet.getInt("NOVELTY_SCORE"),
                        resultSet.getInt("COMPLETED_MISSION_COUNT")), userId);
        return profiles.stream().findFirst();
    }

    public List<Mission> findCandidates(int maximumMinutes, boolean includeLlm) {
        return jdbcTemplate.query("""
                SELECT %s
                  FROM MISSION
                 WHERE ENABLED = 'Y'
                   AND ESTIMATED_MINUTES <= ?
                   AND (? = 1 OR SOURCE_TYPE = 'BASE')
                """.formatted(MISSION_COLUMNS), this::mapMission, maximumMinutes, includeLlm ? 1 : 0);
    }

    public List<Mission> findAllEnabled() {
        return jdbcTemplate.query(
                "SELECT %s FROM MISSION WHERE ENABLED = 'Y'".formatted(MISSION_COLUMNS),
                this::mapMission);
    }

    public Optional<Mission> findById(long missionId) {
        return jdbcTemplate.query(
                "SELECT %s FROM MISSION WHERE MISSION_ID = ?".formatted(MISSION_COLUMNS),
                this::mapMission,
                missionId)
                .stream()
                .findFirst();
    }

    public List<Mission> findRecentCompleted(long userId, int limit) {
        return jdbcTemplate.query("""
                SELECT %s
                  FROM (
                        SELECT m.*, ROW_NUMBER() OVER (
                                   ORDER BY log_row.OCCURRED_AT DESC, log_row.STATUS_LOG_ID DESC
                               ) AS RN
                          FROM MISSION_STATUS_LOG log_row
                          JOIN MISSION m ON m.MISSION_ID = log_row.MISSION_ID
                         WHERE log_row.USER_ID = ?
                           AND log_row.STATUS = 'COMPLETED'
                  )
                 WHERE RN <= ?
                """.formatted(MISSION_COLUMNS), this::mapMission, userId, limit);
    }

    public void updateUserVector(long userId, UserMissionVector vector) {
        requireSingleUpdate(jdbcTemplate.update("""
                UPDATE USER_PERSONALITY_PROFILE
                   SET ACTIVITY_SCORE = ?,
                       SOCIAL_SCORE = ?,
                       PHYSICAL_ACTIVITY_SCORE = ?,
                       NOVELTY_SCORE = ?,
                       COMPLETED_MISSION_COUNT = ?,
                       UPDATED_AT = CURRENT_TIMESTAMP
                 WHERE USER_ID = ?
                """,
                vector.indoorOutdoor(),
                vector.socialLevel(),
                vector.activityLevel(),
                vector.noveltyLevel(),
                vector.completedMissionCount(),
                userId));
    }

    public void updatePersonalityClassification(
            long userId,
            String personalityCode,
            int adaptedCompletionCount) {
        requireSingleUpdate(jdbcTemplate.update("""
                UPDATE USER_PERSONALITY_PROFILE
                   SET PERSONALITY_CODE = ?,
                       LAST_MISSION_ADAPTED_COUNT = ?,
                       UPDATED_AT = CURRENT_TIMESTAMP
                 WHERE USER_ID = ?
                """, personalityCode, adaptedCompletionCount, userId));
    }

    public long insertGenerated(GeneratedMission generated) {
            Long missionId = jdbcTemplate.queryForObject("SELECT nextval('mission_seq')", Long.class);
            if (missionId == null) {
            throw new IllegalStateException("PostgreSQL did not return a mission ID.");
        }
        jdbcTemplate.update("""
                INSERT INTO MISSION (
                    MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY,
                    DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL,
                    ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL,
                    UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS,
                    ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Y', 'LLM', ?)
                """,
                missionId,
                generated.title(),
                MissionSimilarityPolicy.normalize(generated.title()),
                generated.description(),
                generated.category().name(),
                generated.difficulty(),
                generated.estimatedMinutes(),
                generated.indoorOutdoor(),
                generated.socialLevel(),
                generated.activityLevel(),
                generated.noveltyLevel(),
                generated.actionType().name(),
                generated.creativityLevel(),
                generated.unpredictabilityLevel(),
                generated.comfortZoneDistance(),
                generated.costLevel(),
                serializeTags(generated.tags()),
                fingerprint(generated.title(), generated.description()));
        return missionId;
    }

    public boolean claimGeneration(long userId, int milestone, String modelName) {
        List<String> statuses = jdbcTemplate.query(
                """
                SELECT STATUS
                  FROM MISSION_LLM_GENERATION
                 WHERE USER_ID = ? AND COMPLETION_MILESTONE = ?
                """,
                (resultSet, rowNumber) -> resultSet.getString("STATUS"),
                userId,
                milestone);
        if (!statuses.isEmpty()) {
            return false;
        }

        try {
            Long generationId = jdbcTemplate.queryForObject(
                    "SELECT nextval('mission_llm_generation_seq')", Long.class);
            jdbcTemplate.update("""
                    INSERT INTO MISSION_LLM_GENERATION (
                        GENERATION_ID, USER_ID, COMPLETION_MILESTONE, STATUS, MODEL_NAME
                    ) VALUES (?, ?, ?, 'PENDING', ?)
                    """, generationId, userId, milestone, modelName);
            return true;
        } catch (DuplicateKeyException exception) {
            return false;
        }
    }

    public void completeGeneration(long userId, int milestone, long missionId) {
        jdbcTemplate.update("""
                UPDATE MISSION_LLM_GENERATION
                   SET STATUS = 'COMPLETED', MISSION_ID = ?, ERROR_CODE = NULL,
                       UPDATED_AT = CURRENT_TIMESTAMP
                 WHERE USER_ID = ? AND COMPLETION_MILESTONE = ?
                """, missionId, userId, milestone);
    }

    public void failGeneration(long userId, int milestone, String errorCode) {
        jdbcTemplate.update("""
                UPDATE MISSION_LLM_GENERATION
                   SET STATUS = 'FAILED', ERROR_CODE = ?, UPDATED_AT = CURRENT_TIMESTAMP
                 WHERE USER_ID = ? AND COMPLETION_MILESTONE = ?
                """, errorCode, userId, milestone);
    }

    private Mission mapMission(java.sql.ResultSet resultSet, int rowNumber) throws java.sql.SQLException {
        return new Mission(
                resultSet.getLong("MISSION_ID"),
                resultSet.getString("TITLE"),
                resultSet.getString("DESCRIPTION"),
                MissionCategory.valueOf(resultSet.getString("CATEGORY")),
                resultSet.getInt("DIFFICULTY"),
                resultSet.getInt("ESTIMATED_MINUTES"),
                resultSet.getInt("INDOOR_OUTDOOR"),
                resultSet.getInt("SOCIAL_LEVEL"),
                resultSet.getInt("ACTIVITY_LEVEL"),
                resultSet.getInt("NOVELTY_LEVEL"),
                MissionActionType.valueOf(resultSet.getString("ACTION_TYPE")),
                resultSet.getInt("CREATIVITY_LEVEL"),
                resultSet.getInt("UNPREDICTABILITY_LEVEL"),
                resultSet.getInt("COMFORT_ZONE_DISTANCE"),
                resultSet.getInt("COST_LEVEL"),
                parseTags(resultSet.getString("TAGS")),
                "Y".equals(resultSet.getString("ENABLED")),
                MissionSourceType.valueOf(resultSet.getString("SOURCE_TYPE")));
    }

    static Set<String> parseTags(String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("mission tags are required.");
        }
        return Arrays.stream(value.split(","))
                .map(String::trim)
                .filter(tag -> !tag.isEmpty())
                .collect(Collectors.toUnmodifiableSet());
    }

    static String serializeTags(Set<String> tags) {
        return tags.stream().sorted().collect(Collectors.joining(","));
    }

    private String fingerprint(String title, String description) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest((title + "|" + description).getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is not available.", exception);
        }
    }

    private void requireSingleUpdate(int updatedRows) {
        if (updatedRows != 1) {
            throw new IllegalStateException("Unexpected personality profile update count.");
        }
    }
}
