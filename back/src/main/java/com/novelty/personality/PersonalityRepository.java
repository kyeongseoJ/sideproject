package com.novelty.personality;

import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.dao.DataRetrievalFailureException;
import org.springframework.dao.IncorrectUpdateSemanticsDataAccessException;
import org.springframework.stereotype.Repository;

import com.novelty.config.ServiceTimeConfig;
import com.novelty.user.UserPersonalityResponse;

@Repository
public class PersonalityRepository {

    private static final String LOCK_USER_SQL = """
            SELECT USER_ID
              FROM NOVELTY_USER
             WHERE USER_ID = ?
               FOR UPDATE
            """;

    private static final String FIND_SUBMISSION_SQL = """
            SELECT SURVEY_ID,
                   ACTIVITY_LEVEL,
                   SOCIAL_ACTIVITY,
                   PHYSICAL_ACTIVITY_LEVEL,
                   NOVELTY_TOLERANCE,
                   EXECUTION_STYLE,
                   ANALYSIS_MODE,
                   ANALYSIS_VERSION,
                   CREATED_AT
              FROM SURVEY_RESPONSE
             WHERE USER_ID = ?
               AND SUBMISSION_KEY = ?
            """;

    private static final String FIND_SUBMISSION_INTERESTS_SQL = """
            SELECT INTEREST_CODE
              FROM SURVEY_INTEREST
             WHERE SURVEY_ID = ?
             ORDER BY INTEREST_CODE
            """;

    private static final String PROFILE_EXISTS_SQL = """
            SELECT COUNT(*)
              FROM USER_PERSONALITY_PROFILE
             WHERE USER_ID = ?
            """;

    private static final String INSERT_SUBMISSION_SQL = """
            INSERT INTO SURVEY_RESPONSE (
                SURVEY_ID,
                USER_ID,
                SUBMISSION_KEY,
                ACTIVITY_LEVEL,
                SOCIAL_ACTIVITY,
                PHYSICAL_ACTIVITY_LEVEL,
                NOVELTY_TOLERANCE,
                EXECUTION_STYLE,
                ANALYSIS_MODE,
                ANALYSIS_VERSION,
                ENERGY_LEVEL,
                CREATED_AT
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?)
            """;

    private static final String INSERT_SUBMISSION_INTEREST_SQL = """
            INSERT INTO SURVEY_INTEREST (SURVEY_ID, INTEREST_CODE)
            VALUES (?, ?)
            """;

    private static final String INSERT_PROFILE_SQL = """
            INSERT INTO USER_PERSONALITY_PROFILE (
                USER_ID,
                PERSONALITY_CODE,
                ACTIVITY_SCORE,
                SOCIAL_SCORE,
                PHYSICAL_ACTIVITY_SCORE,
                NOVELTY_SCORE,
                EXECUTION_STYLE,
                SOURCE_SURVEY_ID,
                ANALYSIS_VERSION,
                ANALYZED_AT,
                UPDATED_AT
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """;

    private static final String UPDATE_PROFILE_SQL = """
            UPDATE USER_PERSONALITY_PROFILE
               SET PERSONALITY_CODE = ?,
                   ACTIVITY_SCORE = ?,
                   SOCIAL_SCORE = ?,
                   PHYSICAL_ACTIVITY_SCORE = ?,
                   NOVELTY_SCORE = ?,
                   EXECUTION_STYLE = ?,
                   SOURCE_SURVEY_ID = ?,
                   ANALYSIS_VERSION = ?,
                   ANALYZED_AT = ?,
                   UPDATED_AT = ?
             WHERE USER_ID = ?
            """;

    private static final String DELETE_PROFILE_INTERESTS_SQL = """
            DELETE FROM USER_PROFILE_INTEREST
             WHERE USER_ID = ?
            """;

    private static final String INSERT_PROFILE_INTEREST_SQL = """
            INSERT INTO USER_PROFILE_INTEREST (USER_ID, INTEREST_CODE)
            VALUES (?, ?)
            """;

    private static final String FIND_PROFILE_SQL = """
            SELECT p.PERSONALITY_CODE,
                   p.ACTIVITY_SCORE,
                   p.SOCIAL_SCORE,
                   p.PHYSICAL_ACTIVITY_SCORE,
                   p.NOVELTY_SCORE,
                   p.EXECUTION_STYLE,
                   p.ANALYSIS_VERSION,
                   p.ANALYZED_AT,
                   CASE p.ACTIVITY_SCORE
                       WHEN -1 THEN 'INDOOR'
                       WHEN 0 THEN 'MIXED'
                       ELSE 'OUTDOOR'
                   END ACTIVITY_LEVEL,
                   CASE p.SOCIAL_SCORE
                       WHEN -1 THEN 'LOW'
                       WHEN 0 THEN 'MEDIUM'
                       ELSE 'HIGH'
                   END SOCIAL_ACTIVITY,
                   CASE p.PHYSICAL_ACTIVITY_SCORE
                       WHEN 0 THEN 'LOW'
                       WHEN 1 THEN 'MEDIUM'
                       ELSE 'HIGH'
                   END PHYSICAL_ACTIVITY_LEVEL,
                   CASE p.NOVELTY_SCORE
                       WHEN 0 THEN 'LOW'
                       WHEN 1 THEN 'MEDIUM'
                       ELSE 'HIGH'
                   END NOVELTY_TOLERANCE
              FROM USER_PERSONALITY_PROFILE p
             WHERE p.USER_ID = ?
            """;

    private static final String FIND_PROFILE_INTERESTS_SQL = """
            SELECT INTEREST_CODE
              FROM USER_PROFILE_INTEREST
             WHERE USER_ID = ?
             ORDER BY INTEREST_CODE
            """;

    private static final String TOUCH_USER_SQL = """
            UPDATE NOVELTY_USER
               SET LAST_SEEN_AT = ?
             WHERE USER_ID = ?
            """;

    private final JdbcTemplate jdbcTemplate;

    public PersonalityRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void lockUser(long userId) {
        jdbcTemplate.queryForObject(LOCK_USER_SQL, Long.class, userId);
    }

    Optional<StoredPersonalitySubmission> findSubmission(long userId, String submissionKey) {
        List<StoredPersonalitySubmission> submissions = jdbcTemplate.query(
                FIND_SUBMISSION_SQL,
                (resultSet, rowNumber) -> {
                    long analysisId = resultSet.getLong("SURVEY_ID");
                    return new StoredPersonalitySubmission(
                            analysisId,
                            AnalysisMode.valueOf(resultSet.getString("ANALYSIS_MODE")),
                            new PersonalityAnswers(
                                    IndoorOutdoor.valueOf(resultSet.getString("ACTIVITY_LEVEL")),
                                    SocialLevel.valueOf(resultSet.getString("SOCIAL_ACTIVITY")),
                                    PhysicalActivityLevel.valueOf(
                                            resultSet.getString("PHYSICAL_ACTIVITY_LEVEL")),
                                    NoveltyLevel.valueOf(resultSet.getString("NOVELTY_TOLERANCE")),
                                    findSubmissionInterests(analysisId),
                                    ExecutionStyle.valueOf(resultSet.getString("EXECUTION_STYLE"))),
                            resultSet.getString("ANALYSIS_VERSION"),
                            toOffsetDateTime(resultSet.getTimestamp("CREATED_AT")));
                },
                userId,
                submissionKey);
        return submissions.stream().findFirst();
    }

    boolean profileExists(long userId) {
        Integer count = jdbcTemplate.queryForObject(PROFILE_EXISTS_SQL, Integer.class, userId);
        return count != null && count > 0;
    }

    long nextAnalysisId() {
        Long analysisId = jdbcTemplate.queryForObject(
                "SELECT SURVEY_RESPONSE_SEQ.NEXTVAL FROM DUAL",
                Long.class);
        if (analysisId == null) {
            throw new DataRetrievalFailureException("Oracle did not return an analysis ID.");
        }
        return analysisId;
    }

    void insertSubmission(
            long analysisId,
            long userId,
            String submissionKey,
            AnalysisMode analysisMode,
            PersonalityAnswers answers,
            OffsetDateTime analyzedAt) {
        jdbcTemplate.update(
                INSERT_SUBMISSION_SQL,
                analysisId,
                userId,
                submissionKey,
                answers.indoorOutdoor().name(),
                answers.socialLevel().name(),
                answers.physicalActivityLevel().name(),
                answers.noveltyLevel().name(),
                answers.executionStyle().name(),
                analysisMode.name(),
                PersonalityAnalysis.CURRENT_VERSION,
                toTimestamp(analyzedAt));

        List<Object[]> parameters = answers.interests().stream()
                .map(interest -> new Object[] {analysisId, interest.name()})
                .toList();
        jdbcTemplate.batchUpdate(INSERT_SUBMISSION_INTEREST_SQL, parameters);
    }

    void insertProfile(
            long userId,
            long analysisId,
            PersonalityAnalysis analysis,
            OffsetDateTime analyzedAt) {
        Timestamp timestamp = toTimestamp(analyzedAt);
        jdbcTemplate.update(
                INSERT_PROFILE_SQL,
                userId,
                analysis.type().name(),
                analysis.indoorOutdoorScore(),
                analysis.socialLevelScore(),
                analysis.physicalActivityLevelScore(),
                analysis.noveltyLevelScore(),
                analysis.executionStyle().name(),
                analysisId,
                analysis.analysisVersion(),
                timestamp,
                timestamp);
    }

    void updateProfile(
            long userId,
            long analysisId,
            PersonalityAnalysis analysis,
            OffsetDateTime analyzedAt) {
        Timestamp timestamp = toTimestamp(analyzedAt);
        int updated = jdbcTemplate.update(
                UPDATE_PROFILE_SQL,
                analysis.type().name(),
                analysis.indoorOutdoorScore(),
                analysis.socialLevelScore(),
                analysis.physicalActivityLevelScore(),
                analysis.noveltyLevelScore(),
                analysis.executionStyle().name(),
                analysisId,
                analysis.analysisVersion(),
                timestamp,
                timestamp,
                userId);
        if (updated != 1) {
            throw new IncorrectUpdateSemanticsDataAccessException(
                    "Current personality profile was not updated.");
        }
    }

    void replaceProfileInterests(long userId, List<Interest> interests) {
        jdbcTemplate.update(DELETE_PROFILE_INTERESTS_SQL, userId);
        List<Object[]> parameters = interests.stream()
                .map(interest -> new Object[] {userId, interest.name()})
                .toList();
        jdbcTemplate.batchUpdate(INSERT_PROFILE_INTEREST_SQL, parameters);
    }

    public Optional<UserPersonalityResponse> findCurrentProfile(long userId) {
        List<UserPersonalityResponse> profiles = jdbcTemplate.query(
                FIND_PROFILE_SQL,
                (resultSet, rowNumber) -> {
                    PersonalityType type = PersonalityType.valueOf(
                            resultSet.getString("PERSONALITY_CODE"));
                    return new UserPersonalityResponse(
                            type.name(),
                            type.displayName(),
                            type.summary(),
                            IndoorOutdoor.valueOf(resultSet.getString("ACTIVITY_LEVEL")),
                            resultSet.getInt("ACTIVITY_SCORE"),
                            SocialLevel.valueOf(resultSet.getString("SOCIAL_ACTIVITY")),
                            resultSet.getInt("SOCIAL_SCORE"),
                            PhysicalActivityLevel.valueOf(
                                    resultSet.getString("PHYSICAL_ACTIVITY_LEVEL")),
                            resultSet.getInt("PHYSICAL_ACTIVITY_SCORE"),
                            NoveltyLevel.valueOf(resultSet.getString("NOVELTY_TOLERANCE")),
                            resultSet.getInt("NOVELTY_SCORE"),
                            ExecutionStyle.valueOf(resultSet.getString("EXECUTION_STYLE")),
                            findProfileInterests(userId),
                            resultSet.getString("ANALYSIS_VERSION"),
                            toOffsetDateTime(resultSet.getTimestamp("ANALYZED_AT")));
                },
                userId);
        return profiles.stream().findFirst();
    }

    void touchUser(long userId, OffsetDateTime seenAt) {
        jdbcTemplate.update(TOUCH_USER_SQL, toTimestamp(seenAt), userId);
    }

    private List<Interest> findSubmissionInterests(long analysisId) {
        return jdbcTemplate.query(
                FIND_SUBMISSION_INTERESTS_SQL,
                (resultSet, rowNumber) -> Interest.valueOf(resultSet.getString("INTEREST_CODE")),
                analysisId);
    }

    private List<Interest> findProfileInterests(long userId) {
        return jdbcTemplate.query(
                FIND_PROFILE_INTERESTS_SQL,
                (resultSet, rowNumber) -> Interest.valueOf(resultSet.getString("INTEREST_CODE")),
                userId);
    }

    private Timestamp toTimestamp(OffsetDateTime value) {
        return Timestamp.valueOf(value.atZoneSameInstant(ServiceTimeConfig.SERVICE_ZONE).toLocalDateTime());
    }

    private OffsetDateTime toOffsetDateTime(Timestamp value) {
        LocalDateTime localDateTime = value.toLocalDateTime();
        return localDateTime.atZone(ServiceTimeConfig.SERVICE_ZONE).toOffsetDateTime();
    }
}
