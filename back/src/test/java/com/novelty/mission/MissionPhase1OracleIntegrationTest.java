package com.novelty.mission;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.Date;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;

@EnabledIfEnvironmentVariable(named = "RUN_ORACLE_INTEGRATION", matches = "true")
class MissionPhase1OracleIntegrationTest {

    private static final String DEFAULT_DB_URL = "jdbc:oracle:thin:@localhost:1521:XE";
    private static final String MIGRATION_START = "-- MISSION_V1_PHASE1_START";
    private static final String MIGRATION_END = "-- MISSION_V1_PHASE1_END";

    private static final long FIRST_USER_ID = -9_310_000_001L;
    private static final long SECOND_USER_ID = -9_310_000_002L;
    private static final long FIRST_MISSION_ID = -9_320_000_001L;
    private static final long SECOND_MISSION_ID = -9_320_000_002L;
    private static final long THIRD_MISSION_ID = -9_320_000_003L;
    private static final long SURVEY_ID = -9_330_000_001L;

    @Test
    @Timeout(90)
    void appliesMissionSchemaIdempotentlyAndEnforcesNormalAndFailureContracts() throws Exception {
        String username = requireEnvironment("DB_USERNAME");
        String password = requireEnvironment("DB_PASSWORD");
        String url = environmentOrDefault("DB_URL", DEFAULT_DB_URL);

        try (Connection connection = DriverManager.getConnection(url, username, password)) {
            assertPrerequisites(connection);
            Baseline before = readBaseline(connection);

            applyMissionMigration(connection);
            assertSchema(connection);
            assertEquals(before, readBaseline(connection), "Migration must preserve existing row counts.");

            applyMissionMigration(connection);
            assertSchema(connection);
            assertEquals(before, readBaseline(connection), "Re-running migration must be idempotent.");

            verifyNormalAndFailureScenarios(connection);
            assertEquals(before, readBaseline(connection), "Verification fixtures must be rolled back.");

            System.out.printf(
                    Locale.ROOT,
                    "MISSION_PHASE1_BASELINE userMissions=%d statusLogs=%d profiles=%d%n",
                    before.userMissions(),
                    before.statusLogs(),
                    before.profiles());
            System.out.println("MISSION_PHASE1_ORACLE_VERIFICATION=PASS");
        }
    }

    private void assertPrerequisites(Connection connection) throws SQLException {
        assertTrue(tableExists(connection, "NOVELTY_USER"));
        assertTrue(tableExists(connection, "MISSION"));
        assertTrue(tableExists(connection, "MISSION_STATUS_LOG"));
        assertTrue(tableExists(connection, "USER_PERSONALITY_PROFILE"));
    }

    private void applyMissionMigration(Connection connection) throws Exception {
        String script = Files.readString(Path.of("..", "DB.sql"));
        int start = script.indexOf(MIGRATION_START);
        int end = script.indexOf(MIGRATION_END);
        assertTrue(start >= 0 && end > start, "Mission Phase 1 migration markers are invalid.");

        String migration = script.substring(start + MIGRATION_START.length(), end);
        List<String> statements = Arrays.stream(migration.split("(?m)^\\s*/\\s*$"))
                .map(String::trim)
                .filter(statement -> !statement.isEmpty())
                .toList();
        assertEquals(17, statements.size(), "Unexpected Mission Phase 1 statement count.");

        boolean previousAutoCommit = connection.getAutoCommit();
        connection.setAutoCommit(true);
        try (Statement statement = connection.createStatement()) {
            for (String sql : statements) {
                statement.execute(sql);
            }
        } finally {
            connection.setAutoCommit(previousAutoCommit);
        }
    }

    private void assertSchema(Connection connection) throws SQLException {
        assertTrue(tableExists(connection, "USER_MISSION_SETTING"));
        assertTrue(tableExists(connection, "USER_MISSION_CATEGORY_STAT"));
        assertTrue(sequenceExists(connection, "USER_MISSION_SEQ"));

        for (String column : List.of(
                "OFFER_BATCH_ID",
                "PERSONALITY_DISTANCE",
                "RECOMMENDATION_SCORE",
                "DAILY_SLOT_NO",
                "SHOWN_AT")) {
            assertTrue(columnExists(connection, "USER_MISSION", column), column);
        }
        assertFalse(columnNullable(connection, "USER_MISSION", "OFFER_BATCH_ID"));
        assertTrue(columnExists(
                connection, "USER_PERSONALITY_PROFILE", "LAST_MISSION_ADAPTED_COUNT"));
        for (String column : List.of("USER_MISSION_ID", "PREVIOUS_STATUS", "CHANGE_REASON")) {
            assertTrue(columnExists(connection, "MISSION_STATUS_LOG", column), column);
        }

        for (String constraint : List.of(
                "CK_USER_MISSION_SERVICE_DATE",
                "CK_USER_MISSION_DISTANCE",
                "CK_USER_MISSION_SCORE",
                "CK_USER_MISSION_SLOT",
                "CK_USER_MISSION_STATUS_SLOT",
                "PK_USER_MISSION_SETTING",
                "FK_USER_MISSION_SETTING_USER",
                "CK_USER_MISSION_SETTING_TIME",
                "CK_USER_MISSION_SETTING_LIMIT",
                "PK_USER_MISSION_CATEGORY_STAT",
                "FK_USER_MISSION_CATEGORY_USER",
                "CK_USER_MISSION_CATEGORY",
                "CK_USER_MISSION_CATEGORY_COUNT",
                "CK_USER_MISSION_CATEGORY_TIME",
                "CK_USER_LAST_MISSION_ADAPTED",
                "FK_MISSION_LOG_USER_MISSION",
                "CK_MISSION_LOG_PREVIOUS_STATUS")) {
            assertTrue(constraintExists(connection, constraint), constraint);
        }
        assertFalse(constraintExists(connection, "UQ_USER_MISSION_DAILY_SLOT"));

        for (String index : List.of(
                "IX_USER_MISSION_OFFER_BATCH",
                "IX_USER_MISSION_USER_DATE",
                "UX_USER_MISSION_ACTIVE_SLOT",
                "IX_USER_MISSION_CATEGORY_COUNT",
                "IX_MISSION_LOG_USER_MISSION_ID")) {
            assertTrue(indexExists(connection, index), index);
        }
    }

    private void verifyNormalAndFailureScenarios(Connection connection) throws SQLException {
        connection.setAutoCommit(false);
        try {
            insertUser(connection, FIRST_USER_ID, "MissionP1A", "C");
            insertUser(connection, SECOND_USER_ID, "MissionP1B", "D");
            insertMission(connection, FIRST_MISSION_ID, "Phase1MissionA", "A", "MOVEMENT");
            insertMission(connection, SECOND_MISSION_ID, "Phase1MissionB", "B", "CULTURE");
            insertMission(connection, THIRD_MISSION_ID, "Phase1MissionC", "E", "FOOD");

            insertSetting(connection, FIRST_USER_ID, "SHORT", 1);
            assertEquals(1, queryLong(
                    connection,
                    "SELECT DAILY_MISSION_LIMIT FROM USER_MISSION_SETTING WHERE USER_ID = ?",
                    FIRST_USER_ID));

            insertCategoryStat(connection, FIRST_USER_ID, "MOVEMENT", 0, null);
            updateCategoryStat(connection, FIRST_USER_ID, "MOVEMENT", 1, testTimestamp());
            assertEquals(1, queryLong(
                    connection,
                    "SELECT COMPLETED_COUNT FROM USER_MISSION_CATEGORY_STAT "
                            + "WHERE USER_ID = ? AND CATEGORY = 'MOVEMENT'",
                    FIRST_USER_ID));

            LocalDate serviceDate = LocalDate.of(2026, 8, 19);
            long shownId = -9_340_000_001L;
            long selectedId = -9_340_000_002L;
            insertUserMission(
                    connection, shownId, FIRST_USER_ID, FIRST_MISSION_ID,
                    "SHOWN", serviceDate, null, 0.75, 0.70);
            insertUserMission(
                    connection, selectedId, FIRST_USER_ID, SECOND_MISSION_ID,
                    "SELECTED", serviceDate, 1, 0.80, 0.76);
            insertStatusLog(connection, shownId, FIRST_USER_ID, FIRST_MISSION_ID, "MOVEMENT");
            assertEquals(2, queryLong(
                    connection,
                    "SELECT COUNT(*) FROM USER_MISSION WHERE USER_ID = ?",
                    FIRST_USER_ID));

            insertLegacySurvey(connection, SURVEY_ID);
            insertProfile(connection, FIRST_USER_ID, SURVEY_ID);
            updateAdaptedCount(connection, FIRST_USER_ID, 5, 5);
            assertEquals(5, queryLong(
                    connection,
                    "SELECT LAST_MISSION_ADAPTED_COUNT FROM USER_PERSONALITY_PROFILE WHERE USER_ID = ?",
                    FIRST_USER_ID));

            assertSqlError(1, () -> insertSetting(connection, FIRST_USER_ID, "SHORT", 1));
            assertSqlError(2290, () -> insertSetting(connection, SECOND_USER_ID, "INVALID", 1));
            assertSqlError(2290, () -> insertSetting(connection, SECOND_USER_ID, "SHORT", 0));
            assertSqlError(2291, () -> insertSetting(connection, -9_399_999_999L, "SHORT", 1));

            assertSqlError(2290, () -> insertCategoryStat(
                    connection, SECOND_USER_ID, "UNKNOWN", 0, null));
            assertSqlError(2290, () -> insertCategoryStat(
                    connection, SECOND_USER_ID, "FOOD", -1, null));
            assertSqlError(2290, () -> insertCategoryStat(
                    connection, SECOND_USER_ID, "FOOD", 1, null));

            assertSqlError(2290, () -> insertUserMission(
                    connection, -9_340_000_011L, SECOND_USER_ID, FIRST_MISSION_ID,
                    "SHOWN", serviceDate, null, 1.1, 0.5));
            assertSqlError(2290, () -> insertUserMission(
                    connection, -9_340_000_012L, SECOND_USER_ID, FIRST_MISSION_ID,
                    "SHOWN", serviceDate, null, 0.5, -0.1));
            assertSqlError(2290, () -> insertUserMission(
                    connection, -9_340_000_013L, SECOND_USER_ID, FIRST_MISSION_ID,
                    "SELECTED", serviceDate, null, 0.5, 0.5));
            assertSqlError(2290, () -> insertUserMission(
                    connection, -9_340_000_014L, SECOND_USER_ID, FIRST_MISSION_ID,
                    "SHOWN", serviceDate, 1, 0.5, 0.5));
            assertSqlError(2290, () -> insertUserMissionWithServiceTimestamp(
                    connection, -9_340_000_015L, SECOND_USER_ID, FIRST_MISSION_ID));
            assertSqlError(1, () -> insertUserMission(
                    connection, -9_340_000_016L, FIRST_USER_ID, THIRD_MISSION_ID,
                    "SELECTED", serviceDate, 1, 0.5, 0.5));
            assertSqlError(1, () -> insertUserMission(
                    connection, -9_340_000_017L, FIRST_USER_ID, FIRST_MISSION_ID,
                    "SHOWN", serviceDate, null, 0.5, 0.5));
            assertSqlError(2291, () -> insertUserMission(
                    connection, -9_340_000_018L, FIRST_USER_ID, -9_399_999_998L,
                    "SHOWN", serviceDate, null, 0.5, 0.5));

            assertSqlError(2290, () -> insertStatusLogWithPrevious(
                    connection, -9_350_000_002L, shownId, FIRST_USER_ID,
                    FIRST_MISSION_ID, "MOVEMENT", "INVALID"));
            assertSqlError(2291, () -> insertStatusLogWithPrevious(
                    connection, -9_350_000_003L, -9_399_999_997L, FIRST_USER_ID,
                    FIRST_MISSION_ID, "MOVEMENT", "SHOWN"));

            updateAdaptedCount(connection, FIRST_USER_ID, 5, 4);
            assertEquals(4, queryLong(
                    connection,
                    "SELECT LAST_MISSION_ADAPTED_COUNT FROM USER_PERSONALITY_PROFILE WHERE USER_ID = ?",
                    FIRST_USER_ID));
            assertSqlError(2290, () -> updateAdaptedCount(connection, FIRST_USER_ID, 5, 10));
        } finally {
            connection.rollback();
            connection.setAutoCommit(true);
        }
    }

    private void insertUser(Connection connection, long userId, String nickname, String hashCharacter)
            throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
                INSERT INTO NOVELTY_USER (
                    USER_ID, USER_KEY_HASH, NICKNAME, NICKNAME_NORMALIZED
                ) VALUES (?, ?, ?, ?)
                """)) {
            statement.setLong(1, userId);
            statement.setString(2, hashCharacter.repeat(64));
            statement.setString(3, nickname);
            statement.setString(4, nickname.toUpperCase(Locale.ROOT));
            statement.executeUpdate();
        }
    }

    private void insertMission(
            Connection connection, long missionId, String title, String fingerprintCharacter, String category)
            throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
                INSERT INTO MISSION (
                    MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY,
                    DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL,
                    ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL,
                    UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS,
                    ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT
                ) VALUES (?, ?, ?, 'Phase 1 verification mission', ?, 1, 5, 0, 0, 1, 1,
                          'EXPLORE', 0, 1, 1, 0, 'PHASE1', 'Y', 'BASE', ?)
                """)) {
            statement.setLong(1, missionId);
            statement.setString(2, title);
            statement.setString(3, title.toUpperCase(Locale.ROOT));
            statement.setString(4, category);
            statement.setString(5, fingerprintCharacter.repeat(64));
            statement.executeUpdate();
        }
    }

    private void insertSetting(Connection connection, long userId, String availableTime, int limit)
            throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
                INSERT INTO USER_MISSION_SETTING (USER_ID, AVAILABLE_TIME, DAILY_MISSION_LIMIT)
                VALUES (?, ?, ?)
                """)) {
            statement.setLong(1, userId);
            statement.setString(2, availableTime);
            statement.setInt(3, limit);
            statement.executeUpdate();
        }
    }

    private void insertCategoryStat(
            Connection connection, long userId, String category, int count, OffsetDateTime lastCompletedAt)
            throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
                INSERT INTO USER_MISSION_CATEGORY_STAT (
                    USER_ID, CATEGORY, COMPLETED_COUNT, LAST_COMPLETED_AT
                ) VALUES (?, ?, ?, ?)
                """)) {
            statement.setLong(1, userId);
            statement.setString(2, category);
            statement.setInt(3, count);
            statement.setObject(4, lastCompletedAt);
            statement.executeUpdate();
        }
    }

    private void updateCategoryStat(
            Connection connection, long userId, String category, int count, OffsetDateTime lastCompletedAt)
            throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
                UPDATE USER_MISSION_CATEGORY_STAT
                   SET COMPLETED_COUNT = ?, LAST_COMPLETED_AT = ?, UPDATED_AT = CURRENT_TIMESTAMP
                 WHERE USER_ID = ? AND CATEGORY = ?
                """)) {
            statement.setInt(1, count);
            statement.setObject(2, lastCompletedAt);
            statement.setLong(3, userId);
            statement.setString(4, category);
            assertEquals(1, statement.executeUpdate());
        }
    }

    private void insertUserMission(
            Connection connection,
            long userMissionId,
            long userId,
            long missionId,
            String status,
            LocalDate serviceDate,
            Integer slot,
            double distance,
            double score) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
                INSERT INTO USER_MISSION (
                    USER_MISSION_ID, USER_ID, MISSION_ID, STATUS, AVAILABLE_TIME,
                    SERVICE_DATE, OFFER_BATCH_ID, PERSONALITY_DISTANCE,
                    RECOMMENDATION_SCORE, DAILY_SLOT_NO, SHOWN_AT, SELECTED_AT
                ) VALUES (?, ?, ?, ?, 'SHORT', ?, 'PHASE1-BATCH', ?, ?, ?, ?, ?)
                """)) {
            statement.setLong(1, userMissionId);
            statement.setLong(2, userId);
            statement.setLong(3, missionId);
            statement.setString(4, status);
            statement.setDate(5, Date.valueOf(serviceDate));
            statement.setDouble(6, distance);
            statement.setDouble(7, score);
            if (slot == null) {
                statement.setNull(8, java.sql.Types.NUMERIC);
            } else {
                statement.setInt(8, slot);
            }
            statement.setObject(9, testTimestamp());
            statement.setObject(10, "SELECTED".equals(status) ? testTimestamp() : null);
            statement.executeUpdate();
        }
    }

    private void insertUserMissionWithServiceTimestamp(
            Connection connection, long userMissionId, long userId, long missionId) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
                INSERT INTO USER_MISSION (
                    USER_MISSION_ID, USER_ID, MISSION_ID, STATUS, AVAILABLE_TIME,
                    SERVICE_DATE, OFFER_BATCH_ID, PERSONALITY_DISTANCE, RECOMMENDATION_SCORE, SHOWN_AT
                ) VALUES (?, ?, ?, 'SHOWN', 'SHORT', ?, 'PHASE1-BATCH', 0.5, 0.5, ?)
                """)) {
            statement.setLong(1, userMissionId);
            statement.setLong(2, userId);
            statement.setLong(3, missionId);
            statement.setTimestamp(4, Timestamp.valueOf("2026-08-19 12:00:00"));
            statement.setObject(5, testTimestamp());
            statement.executeUpdate();
        }
    }

    private void insertStatusLog(
            Connection connection, long userMissionId, long userId, long missionId, String category)
            throws SQLException {
        insertStatusLogWithPrevious(
                connection,
                -9_350_000_001L,
                userMissionId,
                userId,
                missionId,
                category,
                "GENERATED");
    }

    private void insertStatusLogWithPrevious(
            Connection connection,
            long logId,
            long userMissionId,
            long userId,
            long missionId,
            String category,
            String previousStatus) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
                INSERT INTO MISSION_STATUS_LOG (
                    STATUS_LOG_ID, USER_ID, MISSION_ID, CATEGORY, STATUS,
                    USER_MISSION_ID, PREVIOUS_STATUS, CHANGE_REASON
                ) VALUES (?, ?, ?, ?, 'SHOWN', ?, ?, 'PHASE1_TEST')
                """)) {
            statement.setLong(1, logId);
            statement.setLong(2, userId);
            statement.setLong(3, missionId);
            statement.setString(4, category);
            statement.setLong(5, userMissionId);
            statement.setString(6, previousStatus);
            statement.executeUpdate();
        }
    }

    private void insertLegacySurvey(Connection connection, long surveyId) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
                INSERT INTO SURVEY_RESPONSE (
                    SURVEY_ID, ACTIVITY_LEVEL, SOCIAL_ACTIVITY, NOVELTY_TOLERANCE, ENERGY_LEVEL
                ) VALUES (?, 'INDOOR', 'LOW', 'MEDIUM', 'HIGH')
                """)) {
            statement.setLong(1, surveyId);
            statement.executeUpdate();
        }
    }

    private void insertProfile(Connection connection, long userId, long surveyId) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
                INSERT INTO USER_PERSONALITY_PROFILE (
                    USER_ID, PERSONALITY_CODE, ACTIVITY_SCORE, SOCIAL_SCORE,
                    NOVELTY_SCORE, PHYSICAL_ACTIVITY_SCORE, COMPLETED_MISSION_COUNT,
                    EXECUTION_STYLE, SOURCE_SURVEY_ID, ANALYSIS_VERSION
                ) VALUES (?, 'BALANCED_COORDINATOR', 0, 0, 1, 1, 0, 'PLANNED', ?, 'PERSONALITY_V2')
                """)) {
            statement.setLong(1, userId);
            statement.setLong(2, surveyId);
            statement.executeUpdate();
        }
    }

    private void updateAdaptedCount(Connection connection, long userId, int completed, int adapted)
            throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
                UPDATE USER_PERSONALITY_PROFILE
                   SET COMPLETED_MISSION_COUNT = ?, LAST_MISSION_ADAPTED_COUNT = ?
                 WHERE USER_ID = ?
                """)) {
            statement.setInt(1, completed);
            statement.setInt(2, adapted);
            statement.setLong(3, userId);
            assertEquals(1, statement.executeUpdate());
        }
    }

    private OffsetDateTime testTimestamp() {
        return OffsetDateTime.of(2026, 8, 19, 12, 0, 0, 0, ZoneOffset.ofHours(9));
    }

    private Baseline readBaseline(Connection connection) throws SQLException {
        return new Baseline(
                tableExists(connection, "USER_MISSION")
                        ? queryLong(connection, "SELECT COUNT(*) FROM USER_MISSION")
                        : 0,
                queryLong(connection, "SELECT COUNT(*) FROM MISSION_STATUS_LOG"),
                queryLong(connection, "SELECT COUNT(*) FROM USER_PERSONALITY_PROFILE"));
    }

    private boolean tableExists(Connection connection, String tableName) throws SQLException {
        return queryLong(connection, "SELECT COUNT(*) FROM USER_TABLES WHERE TABLE_NAME = ?", tableName) == 1;
    }

    private boolean columnExists(Connection connection, String tableName, String columnName)
            throws SQLException {
        return queryLong(
                        connection,
                        "SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = ? AND COLUMN_NAME = ?",
                        tableName,
                        columnName)
                == 1;
    }

    private boolean columnNullable(Connection connection, String tableName, String columnName)
            throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
                SELECT NULLABLE
                  FROM USER_TAB_COLUMNS
                 WHERE TABLE_NAME = ? AND COLUMN_NAME = ?
                """)) {
            statement.setString(1, tableName);
            statement.setString(2, columnName);
            try (ResultSet resultSet = statement.executeQuery()) {
                assertTrue(resultSet.next());
                return "Y".equals(resultSet.getString(1));
            }
        }
    }

    private boolean constraintExists(Connection connection, String constraintName) throws SQLException {
        return queryLong(
                        connection,
                        "SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_NAME = ?",
                        constraintName)
                == 1;
    }

    private boolean indexExists(Connection connection, String indexName) throws SQLException {
        return queryLong(
                        connection,
                        "SELECT COUNT(*) FROM USER_INDEXES WHERE INDEX_NAME = ?",
                        indexName)
                == 1;
    }

    private boolean sequenceExists(Connection connection, String sequenceName) throws SQLException {
        return queryLong(
                        connection,
                        "SELECT COUNT(*) FROM USER_SEQUENCES WHERE SEQUENCE_NAME = ?",
                        sequenceName)
                == 1;
    }

    private long queryLong(Connection connection, String sql, Object... parameters) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            for (int index = 0; index < parameters.length; index++) {
                statement.setObject(index + 1, parameters[index]);
            }
            try (ResultSet resultSet = statement.executeQuery()) {
                assertTrue(resultSet.next());
                return resultSet.getLong(1);
            }
        }
    }

    private void assertSqlError(int expectedErrorCode, SqlOperation operation) {
        SQLException exception = assertThrows(SQLException.class, operation::run);
        assertEquals(expectedErrorCode, exception.getErrorCode(), exception.getMessage());
    }

    private String requireEnvironment(String name) {
        String value = System.getenv(name);
        if (value == null || value.isBlank()) {
            throw new IllegalStateException(name + " must be set for the Oracle integration test.");
        }
        return value;
    }

    private String environmentOrDefault(String name, String defaultValue) {
        String value = System.getenv(name);
        return value == null || value.isBlank() ? defaultValue : value;
    }

    private record Baseline(long userMissions, long statusLogs, long profiles) {
    }

    @FunctionalInterface
    private interface SqlOperation {
        void run() throws SQLException;
    }
}
