package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

@EnabledIfEnvironmentVariable(named = "RUN_MISSION_PHASE7_DB_VERIFICATION", matches = "true")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE)
class MissionPhase7FlutterOracleVerificationTest {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    @Timeout(60)
    void verifiesFlutterMissionRowsAndCleansUp() {
        long userId = requireUserId();
        try {
            assertThat(count("SELECT COUNT(*) FROM USER_MISSION_SETTING WHERE USER_ID = ?", userId)).isEqualTo(1);
            assertThat(count("SELECT COUNT(*) FROM USER_MISSION WHERE USER_ID = ?", userId)).isGreaterThan(0);
            assertThat(count("SELECT COUNT(*) FROM USER_MISSION WHERE USER_ID = ? AND STATUS = 'COMPLETED'", userId))
                    .isEqualTo(1);
            assertThat(count("SELECT COUNT(*) FROM MISSION_STATUS_LOG WHERE USER_ID = ? AND STATUS = 'COMPLETED'", userId))
                    .isEqualTo(1);
            assertThat(count("SELECT COUNT(*) FROM USER_MISSION_CATEGORY_STAT WHERE USER_ID = ?", userId)).isEqualTo(1);
            assertThat(count("SELECT SUM(COMPLETED_COUNT) FROM USER_MISSION_CATEGORY_STAT WHERE USER_ID = ?", userId))
                    .isEqualTo(1);
            assertThat(count("SELECT COMPLETED_MISSION_COUNT FROM USER_PERSONALITY_PROFILE WHERE USER_ID = ?", userId))
                    .isEqualTo(1);
            System.out.printf("MISSION_PHASE7_ORACLE_VERIFICATION=PASS userId=%d%n", userId);
        } finally {
            cleanup(userId);
            assertThat(count("SELECT COUNT(*) FROM NOVELTY_USER WHERE USER_ID = ?", userId)).isZero();
            System.out.println("MISSION_PHASE7_ORACLE_CLEANUP=PASS");
        }
    }

    private long requireUserId() {
        String raw = System.getenv("MISSION_PHASE7_E2E_USER_ID");
        if (raw == null || raw.isBlank()) {
            throw new IllegalStateException("MISSION_PHASE7_E2E_USER_ID must be set.");
        }
        return Long.parseLong(raw);
    }

    private long count(String sql, long userId) {
        Long value = jdbcTemplate.queryForObject(sql, Long.class, userId);
        return value == null ? 0 : value;
    }

    private void cleanup(long userId) {
        jdbcTemplate.update("DELETE FROM MISSION_STATUS_LOG WHERE USER_ID = ?", userId);
        jdbcTemplate.update("DELETE FROM USER_MISSION_CATEGORY_STAT WHERE USER_ID = ?", userId);
        jdbcTemplate.update("DELETE FROM USER_MISSION WHERE USER_ID = ?", userId);
        jdbcTemplate.update("DELETE FROM USER_MISSION_SETTING WHERE USER_ID = ?", userId);
        jdbcTemplate.update("DELETE FROM USER_PROFILE_INTEREST WHERE USER_ID = ?", userId);
        jdbcTemplate.update("DELETE FROM USER_PERSONALITY_PROFILE WHERE USER_ID = ?", userId);
        jdbcTemplate.update("DELETE FROM SURVEY_INTEREST WHERE SURVEY_ID IN (SELECT SURVEY_ID FROM SURVEY_RESPONSE WHERE USER_ID = ?)", userId);
        jdbcTemplate.update("DELETE FROM SURVEY_RESPONSE WHERE USER_ID = ?", userId);
        jdbcTemplate.update("DELETE FROM NOVELTY_USER WHERE USER_ID = ?", userId);
    }
}
