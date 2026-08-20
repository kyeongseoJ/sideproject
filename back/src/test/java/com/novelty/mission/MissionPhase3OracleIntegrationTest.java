package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.Rollback;
import org.springframework.test.context.transaction.TestTransaction;
import org.springframework.transaction.annotation.Transactional;

import com.novelty.user.AnonymousUserResponse;
import com.novelty.user.UserService;

@SpringBootTest
@EnabledIfEnvironmentVariable(named = "RUN_ORACLE_INTEGRATION", matches = "true")
@Transactional
@Rollback
class MissionPhase3OracleIntegrationTest {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private UserService userService;

    @Autowired
    private MissionService missionService;

    @Test
    @Timeout(90)
    void persistsReusesAndRollsBackDailyRecommendations() {
        Baseline baseline = baseline();
        AnonymousUserResponse user = userService.createAnonymousUser();
        createPersonalityProfile(user.userId());

        MissionSettingsResponse saved = missionService.saveSettings(
                user.userKey(),
                new MissionSettingsRequest(AvailableTime.SHORT, 2));
        assertThat(saved).isEqualTo(new MissionSettingsResponse(AvailableTime.SHORT, 2));
        assertThat(missionService.getSettings(user.userKey())).isEqualTo(saved);

        MissionRecommendationBatchResult created = missionService.recommendToday(user.userKey());
        assertThat(created.created()).isTrue();
        assertThat(created.response().candidates()).isNotEmpty().hasSizeLessThanOrEqualTo(5);
        assertThat(created.response().candidates())
                .allSatisfy(candidate -> {
                    assertThat(candidate.status()).isEqualTo(MissionStatus.SHOWN);
                    assertThat(candidate.userMissionId()).isPositive();
                    assertThat(candidate.personalityDistance()).isBetween(0.0, 1.0);
                    assertThat(candidate.recommendationScore()).isBetween(0.0, 1.0);
                });

        List<Long> firstIds = created.response().candidates().stream()
                .map(UserMissionResponse::userMissionId)
                .toList();
        MissionRecommendationBatchResult reused = missionService.recommendToday(user.userKey());
        assertThat(reused.created()).isFalse();
        assertThat(reused.response().candidates().stream()
                        .map(UserMissionResponse::userMissionId)
                        .toList())
                .containsExactlyElementsOf(firstIds);

        int candidateCount = firstIds.size();
        assertThat(count("SELECT COUNT(*) FROM USER_MISSION WHERE USER_ID = ?", user.userId()))
                .isEqualTo(candidateCount);
        assertThat(count("""
                SELECT COUNT(*)
                  FROM MISSION_STATUS_LOG
                 WHERE USER_ID = ?
                   AND USER_MISSION_ID IS NOT NULL
                   AND STATUS IN ('GENERATED', 'SHOWN')
                """, user.userId())).isEqualTo(candidateCount * 2);
        assertThat(count("""
                SELECT COUNT(*)
                  FROM MISSION_STATUS_LOG
                 WHERE USER_ID = ?
                   AND USER_MISSION_ID IS NULL
                """, user.userId())).isZero();

        AnonymousUserResponse missing = userService.createAnonymousUser();
        assertThatThrownBy(() -> missionService.getSettings(missing.userKey()))
                .isInstanceOf(MissionSettingsRequiredException.class);
        missionService.saveSettings(
                missing.userKey(), new MissionSettingsRequest(AvailableTime.QUICK, 1));
        assertThatThrownBy(() -> missionService.recommendToday(missing.userKey()))
                .isInstanceOf(PersonalityRequiredException.class);
        assertThatThrownBy(() -> missionService.saveSettings(
                        user.userKey(), new MissionSettingsRequest(AvailableTime.SHORT, 0)))
                .isInstanceOf(InvalidMissionRequestException.class);

        TestTransaction.flagForRollback();
        TestTransaction.end();
        assertThat(baseline()).isEqualTo(baseline);
        System.out.println("MISSION_PHASE3_ORACLE_VERIFICATION=PASS");
    }

    private void createPersonalityProfile(long userId) {
        Long surveyId = jdbcTemplate.queryForObject(
                "SELECT SURVEY_RESPONSE_SEQ.NEXTVAL FROM DUAL", Long.class);
        jdbcTemplate.update("""
                INSERT INTO SURVEY_RESPONSE (
                    SURVEY_ID, ACTIVITY_LEVEL, SOCIAL_ACTIVITY,
                    NOVELTY_TOLERANCE, ENERGY_LEVEL
                ) VALUES (?, 'INDOOR', 'LOW', 'MEDIUM', 'LOW')
                """, surveyId);
        jdbcTemplate.update("""
                INSERT INTO USER_PERSONALITY_PROFILE (
                    USER_ID, PERSONALITY_CODE, ACTIVITY_SCORE, SOCIAL_SCORE,
                    NOVELTY_SCORE, PHYSICAL_ACTIVITY_SCORE,
                    COMPLETED_MISSION_COUNT, EXECUTION_STYLE,
                    SOURCE_SURVEY_ID, ANALYSIS_VERSION
                ) VALUES (?, 'QUIET_FOCUSER', -1, -1, 1, 0, 0,
                          'PLANNED', ?, 'PERSONALITY_V2')
                """, userId, surveyId);
    }

    private int count(String sql, Object... parameters) {
        Integer value = jdbcTemplate.queryForObject(sql, Integer.class, parameters);
        return value == null ? 0 : value;
    }

    private Baseline baseline() {
        return new Baseline(
                count("SELECT COUNT(*) FROM NOVELTY_USER"),
                count("SELECT COUNT(*) FROM USER_MISSION_SETTING"),
                count("SELECT COUNT(*) FROM USER_MISSION"),
                count("SELECT COUNT(*) FROM MISSION_STATUS_LOG"),
                count("SELECT COUNT(*) FROM USER_PERSONALITY_PROFILE"),
                count("SELECT COUNT(*) FROM SURVEY_RESPONSE"));
    }

    private record Baseline(
            int users,
            int settings,
            int userMissions,
            int statusLogs,
            int profiles,
            int surveys) {
    }
}
