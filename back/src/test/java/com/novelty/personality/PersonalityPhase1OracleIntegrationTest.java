package com.novelty.personality;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicLong;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;

@EnabledIfEnvironmentVariable(named = "RUN_ORACLE_INTEGRATION", matches = "true")
class PersonalityPhase1OracleIntegrationTest {

    private static final String DEFAULT_DB_URL = "jdbc:oracle:thin:@localhost:1521:XE";
    private static final String MIGRATION_START = "-- PERSONALITY_V2_PHASE1_START";
    private static final String MIGRATION_END = "-- PERSONALITY_V2_PHASE1_END";

    @Test
    @Timeout(60)
    void appliesIdempotentMigrationAndEnforcesV2Constraints() throws Exception {
        String username = requireEnvironment("DB_USERNAME");
        String password = requireEnvironment("DB_PASSWORD");
        String url = environmentOrDefault("DB_URL", DEFAULT_DB_URL);

        try (Connection connection = DriverManager.getConnection(url, username, password)) {
            assertPrerequisites(connection);
            Baseline before = readBaseline(connection);

            applyPhase1Migration(connection);
            assertSchema(connection);
            assertEquals(before, readBaseline(connection), "Migration must preserve existing V1 rows.");

            applyPhase1Migration(connection);
            assertSchema(connection);
            assertEquals(before, readBaseline(connection), "Re-running migration must not change data.");

            verifyNormalAndFailureScenarios(connection);
            assertEquals(before, readBaseline(connection), "All verification fixtures must be rolled back.");

            System.out.printf(
                    Locale.ROOT,
                    "PHASE1_BASELINE responses=%d legacyEnergy=%d profiles=%d v2Profiles=%d%n",
                    before.responses(),
                    before.legacyEnergyResponses(),
                    before.profiles(),
                    before.v2Profiles());
            System.out.println("PHASE1_ORACLE_VERIFICATION=PASS");
        }
    }

    private void assertPrerequisites(Connection connection) throws SQLException {
        assertTrue(tableExists(connection, "SURVEY_RESPONSE"), "SURVEY_RESPONSE must exist before Phase 1.");
        assertTrue(tableExists(connection, "NOVELTY_USER"), "NOVELTY_USER must exist before Phase 1.");
        assertTrue(
                tableExists(connection, "USER_PERSONALITY_PROFILE"),
                "USER_PERSONALITY_PROFILE must exist before Phase 1.");
        assertTrue(columnExists(connection, "SURVEY_RESPONSE", "USER_ID"));
        assertTrue(columnExists(connection, "SURVEY_RESPONSE", "SUBMISSION_KEY"));
        assertTrue(columnExists(connection, "SURVEY_RESPONSE", "EXECUTION_STYLE"));
    }

    private void applyPhase1Migration(Connection connection) throws Exception {
        String script = Files.readString(Path.of("..", "DB.sql"));
        int start = script.indexOf(MIGRATION_START);
        int end = script.indexOf(MIGRATION_END);
        assertTrue(start >= 0 && end > start, "Personality V2 Phase 1 migration markers are invalid.");

        String migration = script.substring(start + MIGRATION_START.length(), end);
        List<String> statements = Arrays.stream(migration.split("(?m)^\\s*/\\s*$"))
                .map(String::trim)
                .filter(statement -> !statement.isEmpty())
                .toList();
        assertEquals(13, statements.size(), "Unexpected number of Phase 1 migration statements.");

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
        assertTrue(columnExists(connection, "SURVEY_RESPONSE", "PHYSICAL_ACTIVITY_LEVEL"));
        assertTrue(columnExists(connection, "SURVEY_RESPONSE", "ANALYSIS_MODE"));
        assertTrue(columnExists(connection, "SURVEY_RESPONSE", "ANALYSIS_VERSION"));
        assertTrue(
                columnLength(connection, "USER_PERSONALITY_PROFILE", "ANALYSIS_VERSION") >= 24,
                "Profile analysis version column must store PERSONALITY_V2.");

        assertTrue(constraintExists(connection, "UQ_SURVEY_USER_SUBMISSION"));
        assertFalse(constraintExists(connection, "UQ_SURVEY_SUBMISSION_KEY"));
        assertTrue(constraintExists(connection, "CK_SURVEY_PHYSICAL_ACTIVITY"));
        assertTrue(constraintExists(connection, "CK_SURVEY_ANALYSIS_MODE"));
        assertTrue(constraintExists(connection, "CK_SURVEY_ANALYSIS_VERSION"));
        assertTrue(constraintExists(connection, "CK_SURVEY_V2_REQUIRED_FIELDS"));
    }

    private void verifyNormalAndFailureScenarios(Connection connection) throws SQLException {
        connection.setAutoCommit(false);
        try {
            long firstUserId = -9_100_000_001L;
            long secondUserId = -9_100_000_002L;
            AtomicLong surveyId = new AtomicLong(-9_200_000_001L);
            insertUser(connection, firstUserId);
            insertUser(connection, secondUserId);

            long legacySurveyId = surveyId.getAndDecrement();
            insertLegacySurvey(connection, legacySurveyId);
            assertEquals(
                    "HIGH",
                    queryString(
                            connection,
                            "SELECT ENERGY_LEVEL FROM SURVEY_RESPONSE WHERE SURVEY_ID = ?",
                            legacySurveyId));

            String sharedSubmissionKey = "00000000-0000-0000-0000-000000000001";
            insertV2Survey(
                    connection,
                    surveyId.getAndDecrement(),
                    firstUserId,
                    sharedSubmissionKey,
                    "LOW",
                    "INITIAL",
                    "PERSONALITY_V2",
                    null);

            insertV2Survey(
                    connection,
                    surveyId.getAndDecrement(),
                    secondUserId,
                    sharedSubmissionKey,
                    "MEDIUM",
                    "INITIAL",
                    "PERSONALITY_V2",
                    null);

            assertSqlError(
                    1,
                    () -> insertV2Survey(
                            connection,
                            surveyId.getAndDecrement(),
                            firstUserId,
                            sharedSubmissionKey,
                            "HIGH",
                            "REANALYSIS",
                            "PERSONALITY_V2",
                            null));

            assertSqlError(
                    2290,
                    () -> insertV2Survey(
                            connection,
                            surveyId.getAndDecrement(),
                            firstUserId,
                            "00000000-0000-0000-0000-000000000002",
                            "EXTREME",
                            "REANALYSIS",
                            "PERSONALITY_V2",
                            null));

            assertSqlError(
                    2290,
                    () -> insertV2Survey(
                            connection,
                            surveyId.getAndDecrement(),
                            firstUserId,
                            "00000000-0000-0000-0000-000000000003",
                            null,
                            "REANALYSIS",
                            "PERSONALITY_V2",
                            null));

            assertSqlError(
                    2290,
                    () -> insertV2Survey(
                            connection,
                            surveyId.getAndDecrement(),
                            firstUserId,
                            "00000000-0000-0000-0000-000000000004",
                            "LOW",
                            "AUTOMATIC",
                            "PERSONALITY_V2",
                            null));

            assertSqlError(
                    2290,
                    () -> insertV2Survey(
                            connection,
                            surveyId.getAndDecrement(),
                            firstUserId,
                            "00000000-0000-0000-0000-000000000005",
                            "LOW",
                            "REANALYSIS",
                            "UNKNOWN_VERSION",
                            null));

            assertSqlError(
                    2290,
                    () -> insertV2Survey(
                            connection,
                            surveyId.getAndDecrement(),
                            firstUserId,
                            "00000000-0000-0000-0000-000000000006",
                            "LOW",
                            "REANALYSIS",
                            "PERSONALITY_V2",
                            "HIGH"));
        } finally {
            connection.rollback();
            connection.setAutoCommit(true);
        }
    }

    private void insertUser(Connection connection, long userId) throws SQLException {
        long fixtureNumber = Math.abs(userId % 10);
        String nickname = "P1TEST" + fixtureNumber;
        String userKeyHash = (fixtureNumber % 2 == 0 ? "A" : "B").repeat(64);
        try (PreparedStatement statement = connection.prepareStatement("""
                INSERT INTO NOVELTY_USER (
                    USER_ID, USER_KEY_HASH, NICKNAME, NICKNAME_NORMALIZED
                ) VALUES (?, ?, ?, ?)
                """)) {
            statement.setLong(1, userId);
            statement.setString(2, userKeyHash);
            statement.setString(3, nickname);
            statement.setString(4, nickname);
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

    private void insertV2Survey(
            Connection connection,
            long surveyId,
            long userId,
            String submissionKey,
            String physicalActivityLevel,
            String analysisMode,
            String analysisVersion,
            String energyLevel) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
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
                    ENERGY_LEVEL
                ) VALUES (?, ?, ?, 'INDOOR', 'LOW', ?, 'MEDIUM', 'PLANNED', ?, ?, ?)
                """)) {
            statement.setLong(1, surveyId);
            statement.setLong(2, userId);
            statement.setString(3, submissionKey);
            statement.setString(4, physicalActivityLevel);
            statement.setString(5, analysisMode);
            statement.setString(6, analysisVersion);
            statement.setString(7, energyLevel);
            statement.executeUpdate();
        }
    }

    private Baseline readBaseline(Connection connection) throws SQLException {
        return new Baseline(
                queryLong(connection, "SELECT COUNT(*) FROM SURVEY_RESPONSE"),
                queryLong(connection, "SELECT COUNT(*) FROM SURVEY_RESPONSE WHERE ENERGY_LEVEL IS NOT NULL"),
                queryLong(connection, "SELECT COUNT(*) FROM USER_PERSONALITY_PROFILE"),
                queryLong(connection, """
                        SELECT COUNT(*)
                        FROM USER_PERSONALITY_PROFILE
                        WHERE ANALYSIS_VERSION = 'PERSONALITY_V2'
                        """));
    }

    private boolean tableExists(Connection connection, String tableName) throws SQLException {
        return queryLong(
                        connection,
                        "SELECT COUNT(*) FROM USER_TABLES WHERE TABLE_NAME = ?",
                        tableName)
                == 1;
    }

    private boolean columnExists(Connection connection, String tableName, String columnName)
            throws SQLException {
        return queryLong(
                        connection,
                        """
                        SELECT COUNT(*)
                        FROM USER_TAB_COLUMNS
                        WHERE TABLE_NAME = ? AND COLUMN_NAME = ?
                        """,
                        tableName,
                        columnName)
                == 1;
    }

    private long columnLength(Connection connection, String tableName, String columnName)
            throws SQLException {
        return queryLong(
                connection,
                """
                SELECT CHAR_LENGTH
                FROM USER_TAB_COLUMNS
                WHERE TABLE_NAME = ? AND COLUMN_NAME = ?
                """,
                tableName,
                columnName);
    }

    private boolean constraintExists(Connection connection, String constraintName) throws SQLException {
        return queryLong(
                        connection,
                        "SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_NAME = ?",
                        constraintName)
                == 1;
    }

    private long queryLong(Connection connection, String sql, Object... parameters) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            setParameters(statement, parameters);
            try (ResultSet resultSet = statement.executeQuery()) {
                assertTrue(resultSet.next());
                return resultSet.getLong(1);
            }
        }
    }

    private String queryString(Connection connection, String sql, Object... parameters) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            setParameters(statement, parameters);
            try (ResultSet resultSet = statement.executeQuery()) {
                assertTrue(resultSet.next());
                return resultSet.getString(1);
            }
        }
    }

    private void setParameters(PreparedStatement statement, Object... parameters) throws SQLException {
        for (int index = 0; index < parameters.length; index++) {
            statement.setObject(index + 1, parameters[index]);
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

    private record Baseline(
            long responses,
            long legacyEnergyResponses,
            long profiles,
            long v2Profiles) {
    }

    @FunctionalInterface
    private interface SqlOperation {
        void run() throws SQLException;
    }
}
