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
import com.novelty.world.WorldProgressService;

@SpringBootTest
@EnabledIfEnvironmentVariable(named = "RUN_ORACLE_INTEGRATION", matches = "true")
@Transactional
@Rollback
class MissionPhase4OracleIntegrationTest {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private UserService userService;

    @Autowired
    private MissionService missionService;

    @Autowired
    private UserMissionService userMissionService;

    @Autowired
    private WorldProgressService worldProgressService;

    @Test
    @Timeout(90)
    void transitionsReplacesCompletesIdempotentlyAndRollsBack() {
        Baseline baseline = baseline();
        AnonymousUserResponse user = userService.createAnonymousUser();
        createPersonalityProfile(user.userId());
        missionService.saveSettings(
                user.userKey(), new MissionSettingsRequest(AvailableTime.SHORT, 2));
        List<UserMissionResponse> candidates = missionService
                .recommendToday(user.userKey())
                .response()
                .candidates();
        assertThat(candidates).hasSize(5);

        long first = candidates.get(0).userMissionId();
        long second = candidates.get(1).userMissionId();
        long third = candidates.get(2).userMissionId();

        UserMissionActionResponse selected = userMissionService.select(user.userKey(), first);
        assertThat(selected.mission().status()).isEqualTo(MissionStatus.SELECTED);
        assertThat(selected.today().activeMissions()).hasSize(1);

        UserMissionActionResponse cancelled = userMissionService.cancel(user.userKey(), first);
        assertThat(cancelled.mission().status()).isEqualTo(MissionStatus.CANCELLED);
        assertThat(cancelled.today().activeMissions()).isEmpty();

        userMissionService.select(user.userKey(), first);
        UserMissionActionResponse replaced = userMissionService.replace(
                user.userKey(), first, new ReplacementMissionRequest(second));
        assertThat(replaced.mission().userMissionId()).isEqualTo(second);
        assertThat(replaced.mission().status()).isEqualTo(MissionStatus.SELECTED);
        assertThat(status(first)).isEqualTo("CANCELLED");
        assertThat(slot(first)).isNull();
        assertThat(status(second)).isEqualTo("SELECTED");
        assertThat(slot(second)).isEqualTo(1);

        UserMissionActionResponse completed = userMissionService.complete(user.userKey(), second);
        assertThat(completed.mission().status()).isEqualTo(MissionStatus.COMPLETED);
        assertThat(completed.idempotent()).isFalse();
        assertThat(completed.completion().worldGrowth().rewardApplied()).isTrue();
        assertThat(completed.completion().worldGrowth().awardedExp()).isBetween(10, 30);
        assertThat(count("SELECT COUNT(*) FROM USER_WORLD_OBJECT WHERE USER_ID = ?", user.userId()))
                .isEqualTo(1);
        assertThat(worldProgressService.getSnapshot(user.userKey()).objects())
                .anySatisfy(object -> {
                    assertThat(object.objectCode())
                            .isEqualTo(completed.completion().worldGrowth().objectCode());
                    assertThat(object.exp())
                            .isEqualTo(completed.completion().worldGrowth().currentExp());
                });
        int completedLogCount = statusLogCount(second, "COMPLETED");
        UserMissionActionResponse retry = userMissionService.complete(user.userKey(), second);
        assertThat(retry.idempotent()).isTrue();
        assertThat(retry.completion().worldGrowth().rewardApplied()).isFalse();
        assertThat(statusLogCount(second, "COMPLETED")).isEqualTo(completedLogCount);
        assertThat(profileCompletionCount(user.userId())).isEqualTo(1);

        userMissionService.select(user.userKey(), third);
        assertThatThrownBy(() -> userMissionService.select(user.userKey(), first))
                .isInstanceOf(DailyLimitReachedException.class);
        assertThatThrownBy(() -> missionService.saveSettings(
                        user.userKey(), new MissionSettingsRequest(AvailableTime.SHORT, 1)))
                .isInstanceOf(DailyLimitReachedException.class);

        AnonymousUserResponse other = userService.createAnonymousUser();
        missionService.saveSettings(
                other.userKey(), new MissionSettingsRequest(AvailableTime.QUICK, 1));
        assertThatThrownBy(() -> userMissionService.cancel(other.userKey(), third))
                .isInstanceOf(UserMissionNotFoundException.class);
        assertThatThrownBy(() -> userMissionService.replace(
                        user.userKey(), third, new ReplacementMissionRequest(-1)))
                .isInstanceOf(InvalidMissionRequestException.class);
        assertThatThrownBy(() -> userMissionService.cancel(user.userKey(), second))
                .isInstanceOf(InvalidMissionTransitionException.class);

        assertThat(count("""
                SELECT COUNT(*)
                  FROM MISSION_STATUS_LOG
                 WHERE USER_ID = ?
                   AND USER_MISSION_ID IS NOT NULL
                   AND PREVIOUS_STATUS IS NOT NULL
                """, user.userId())).isGreaterThanOrEqualTo(6);
        assertThat(count("""
                SELECT COUNT(*)
                  FROM USER_MISSION
                 WHERE USER_ID = ?
                   AND STATUS IN ('SELECTED', 'COMPLETED')
                   AND DAILY_SLOT_NO IS NOT NULL
                """, user.userId())).isEqualTo(2);

        TestTransaction.flagForRollback();
        TestTransaction.end();
        assertThat(baseline()).isEqualTo(baseline);
        System.out.println("MISSION_PHASE4_ORACLE_VERIFICATION=PASS");
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

    private String status(long userMissionId) {
        return jdbcTemplate.queryForObject(
                "SELECT STATUS FROM USER_MISSION WHERE USER_MISSION_ID = ?",
                String.class,
                userMissionId);
    }

    private Integer slot(long userMissionId) {
        return jdbcTemplate.queryForObject(
                "SELECT DAILY_SLOT_NO FROM USER_MISSION WHERE USER_MISSION_ID = ?",
                Integer.class,
                userMissionId);
    }

    private int statusLogCount(long userMissionId, String status) {
        return count("""
                SELECT COUNT(*) FROM MISSION_STATUS_LOG
                 WHERE USER_MISSION_ID = ? AND STATUS = ?
                """, userMissionId, status);
    }

    private int profileCompletionCount(long userId) {
        return count("""
                SELECT COMPLETED_MISSION_COUNT FROM USER_PERSONALITY_PROFILE
                 WHERE USER_ID = ?
                """, userId);
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
