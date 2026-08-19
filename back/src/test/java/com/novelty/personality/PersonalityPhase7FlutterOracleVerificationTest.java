package com.novelty.personality;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

@EnabledIfEnvironmentVariable(named = "RUN_PHASE7_DB_VERIFICATION", matches = "true")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE)
class PersonalityPhase7FlutterOracleVerificationTest {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    @Timeout(60)
    void verifiesFlutterE2eRowsAndCleansUp() {
        long userId = requireUserId();
        try {
            assertThat(count("SELECT COUNT(*) FROM NOVELTY_USER WHERE USER_ID = ?", userId))
                    .isEqualTo(1);
            assertThat(count("""
                    SELECT COUNT(*)
                      FROM NOVELTY_USER
                     WHERE USER_ID = ?
                       AND LENGTH(USER_KEY_HASH) = 64
                    """, userId)).isEqualTo(1);
            assertThat(count("SELECT COUNT(*) FROM SURVEY_RESPONSE WHERE USER_ID = ?", userId))
                    .isEqualTo(2);
            assertThat(count("""
                    SELECT COUNT(*)
                      FROM SURVEY_RESPONSE
                     WHERE USER_ID = ?
                       AND ANALYSIS_VERSION = 'PERSONALITY_V2'
                       AND ENERGY_LEVEL IS NULL
                       AND PHYSICAL_ACTIVITY_LEVEL IS NOT NULL
                    """, userId)).isEqualTo(2);
            assertThat(count("""
                    SELECT COUNT(*)
                      FROM SURVEY_RESPONSE
                     WHERE USER_ID = ? AND ANALYSIS_MODE = 'INITIAL'
                    """, userId)).isEqualTo(1);
            assertThat(count("""
                    SELECT COUNT(*)
                      FROM SURVEY_RESPONSE
                     WHERE USER_ID = ? AND ANALYSIS_MODE = 'REANALYSIS'
                    """, userId)).isEqualTo(1);
            assertThat(count("""
                    SELECT COUNT(*)
                      FROM SURVEY_INTEREST
                     WHERE SURVEY_ID IN (
                         SELECT SURVEY_ID FROM SURVEY_RESPONSE WHERE USER_ID = ?
                     )
                    """, userId)).isEqualTo(2);
            assertThat(count("SELECT COUNT(*) FROM USER_PERSONALITY_PROFILE WHERE USER_ID = ?", userId))
                    .isEqualTo(1);
            assertThat(value("""
                    SELECT PERSONALITY_CODE
                      FROM USER_PERSONALITY_PROFILE
                     WHERE USER_ID = ?
                    """, userId)).isEqualTo("ACTIVE_CONNECTOR");
            assertThat(count("""
                    SELECT COUNT(*)
                      FROM USER_PERSONALITY_PROFILE p
                      JOIN SURVEY_RESPONSE s ON s.SURVEY_ID = p.SOURCE_SURVEY_ID
                     WHERE p.USER_ID = ?
                       AND s.ANALYSIS_MODE = 'REANALYSIS'
                       AND p.ANALYSIS_VERSION = 'PERSONALITY_V2'
                    """, userId)).isEqualTo(1);
            assertThat(count("SELECT COUNT(*) FROM USER_PROFILE_INTEREST WHERE USER_ID = ?", userId))
                    .isEqualTo(1);
            assertThat(value("""
                    SELECT INTEREST_CODE
                      FROM USER_PROFILE_INTEREST
                     WHERE USER_ID = ?
                    """, userId)).isEqualTo("MOVEMENT");

            long legacyCount = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM SURVEY_RESPONSE WHERE ENERGY_LEVEL IS NOT NULL",
                    Long.class);
            assertThat(legacyCount).isGreaterThan(0);
            System.out.printf(
                    "PHASE7_ORACLE_VERIFICATION=PASS userId=%d responses=2 profiles=1 legacy=%d%n",
                    userId,
                    legacyCount);
        } finally {
            cleanup(userId);
            assertThat(count("SELECT COUNT(*) FROM NOVELTY_USER WHERE USER_ID = ?", userId))
                    .isZero();
            System.out.println("PHASE7_ORACLE_CLEANUP=PASS");
        }
    }

    private long requireUserId() {
        String raw = System.getenv("PHASE7_E2E_USER_ID");
        if (raw == null || raw.isBlank()) {
            throw new IllegalStateException("PHASE7_E2E_USER_ID must be set.");
        }
        return Long.parseLong(raw);
    }

    private long count(String sql, long userId) {
        return jdbcTemplate.queryForObject(sql, Long.class, userId);
    }

    private String value(String sql, long userId) {
        return jdbcTemplate.queryForObject(sql, String.class, userId);
    }

    private void cleanup(long userId) {
        jdbcTemplate.update("DELETE FROM USER_PROFILE_INTEREST WHERE USER_ID = ?", userId);
        jdbcTemplate.update("DELETE FROM USER_PERSONALITY_PROFILE WHERE USER_ID = ?", userId);
        jdbcTemplate.update("""
                DELETE FROM SURVEY_INTEREST
                 WHERE SURVEY_ID IN (
                     SELECT SURVEY_ID FROM SURVEY_RESPONSE WHERE USER_ID = ?
                 )
                """, userId);
        jdbcTemplate.update("DELETE FROM SURVEY_RESPONSE WHERE USER_ID = ?", userId);
        jdbcTemplate.update("DELETE FROM NOVELTY_USER WHERE USER_ID = ?", userId);
    }
}
