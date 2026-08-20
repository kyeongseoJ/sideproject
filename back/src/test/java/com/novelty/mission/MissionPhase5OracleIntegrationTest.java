package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.sql.Date;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
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

@SpringBootTest(properties = {
        "novelty.openai.api-key=",
        "novelty.openai.model="
})
@EnabledIfEnvironmentVariable(named = "RUN_ORACLE_INTEGRATION", matches = "true")
@Transactional
@Rollback
class MissionPhase5OracleIntegrationTest {

    private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private UserService userService;

    @Autowired
    private MissionService missionService;

    @Autowired
    private UserMissionService userMissionService;

    @Autowired
    private MissionCompletionRepository completionRepository;

    @Autowired
    private MissionRepository missionRepository;

    @Test
    @Timeout(90)
    void fifthCompletionUpdatesStatsPersonalityAndKeepsLlmOptional() {
        Baseline baseline = baseline();
        AnonymousUserResponse user = userService.createAnonymousUser();
        createPersonalityProfile(user.userId(), 4);
        seedHistoricalCompletions(user.userId(), 4);
        missionService.saveSettings(
                user.userKey(), new MissionSettingsRequest(AvailableTime.SHORT, 1));

        UserMissionResponse candidate = missionService.recommendToday(user.userKey())
                .response()
                .candidates()
                .getFirst();
        userMissionService.select(user.userKey(), candidate.userMissionId());
        UserMissionActionResponse completed = userMissionService.complete(
                user.userKey(), candidate.userMissionId());

        assertThat(completed.idempotent()).isFalse();
        assertThat(completed.completion().summary().completedMissionCount()).isEqualTo(5);
        assertThat(completed.completion().summary().lastPersonalityAdaptedCount()).isEqualTo(5);
        assertThat(completed.completion().personalityUpdated()).isTrue();
        assertThat(completed.completion().milestone()).isEqualTo(5);
        assertThat(completed.completion().llmGenerationStatus()).isEqualTo("NOT_CONFIGURED");
        assertThat(categoryTotal(user.userId())).isEqualTo(5);
        assertThat(profileCount(user.userId())).isEqualTo(5);
        assertThat(lastAdaptedCount(user.userId())).isEqualTo(5);
        assertThat(personalityCode(user.userId())).isEqualTo(
                expectedPersonalityCode(activityScore(user.userId()), socialScore(user.userId())));
        var profile = userService.getCurrentUser(user.userKey()).personality();
        assertThat(profile.typeCode()).isEqualTo(personalityCode(user.userId()));
        assertThat(profile.indoorOutdoor().score()).isEqualTo(activityScore(user.userId()));
        assertThat(profile.socialLevel().score()).isEqualTo(socialScore(user.userId()));
        assertThat(profile.physicalActivityLevel().score())
                .isEqualTo(physicalActivityScore(user.userId()));
        assertThat(profile.noveltyLevel().score()).isEqualTo(noveltyScore(user.userId()));
        assertThat(generationCount(user.userId(), 5)).isZero();

        int completedLogs = completedLogCount(candidate.userMissionId());
        UserMissionActionResponse retry = userMissionService.complete(
                user.userKey(), candidate.userMissionId());
        assertThat(retry.idempotent()).isTrue();
        assertThat(profileCount(user.userId())).isEqualTo(5);
        assertThat(categoryTotal(user.userId())).isEqualTo(5);
        assertThat(completedLogCount(candidate.userMissionId())).isEqualTo(completedLogs);

        TestTransaction.flagForRollback();
        TestTransaction.end();
        assertThat(baseline()).isEqualTo(baseline);
        System.out.println("MISSION_PHASE5_ORACLE_VERIFICATION=PASS");
    }

    @Test
    @Timeout(90)
    void inconsistentFifthCompletionRollsBackStateLogAndStats() {
        Baseline baseline = baseline();
        AnonymousUserResponse user = userService.createAnonymousUser();
        long surveyId = createPersonalityProfile(user.userId(), 4);
        seedHistoricalCompletions(user.userId(), 3);
        missionService.saveSettings(
                user.userKey(), new MissionSettingsRequest(AvailableTime.SHORT, 1));
        UserMissionResponse candidate = missionService.recommendToday(user.userKey())
                .response()
                .candidates()
                .getFirst();
        userMissionService.select(user.userKey(), candidate.userMissionId());
        int categoryBefore = categoryTotal(user.userId());

        TestTransaction.flagForCommit();
        TestTransaction.end();

        try {
            assertThatThrownBy(() -> userMissionService.complete(
                            user.userKey(), candidate.userMissionId()))
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining("inconsistent");

            assertThat(userMissionStatus(candidate.userMissionId())).isEqualTo("SELECTED");
            assertThat(completedLogCount(candidate.userMissionId())).isZero();
            assertThat(categoryTotal(user.userId())).isEqualTo(categoryBefore);
            assertThat(profileCount(user.userId())).isEqualTo(4);
            assertThat(lastAdaptedCount(user.userId())).isZero();
        } finally {
            jdbcTemplate.update("DELETE FROM NOVELTY_USER WHERE USER_ID = ?", user.userId());
            jdbcTemplate.update("DELETE FROM SURVEY_RESPONSE WHERE SURVEY_ID = ?", surveyId);
        }
        assertThat(baseline()).isEqualTo(baseline);
        System.out.println("MISSION_PHASE5_ORACLE_ROLLBACK_VERIFICATION=PASS");
    }

    @Test
    @Timeout(90)
    void validatedLlmMissionIsSharedInCatalogAndMilestoneIsClaimedOnce() {
        Baseline baseline = baseline();
        AnonymousUserResponse user = userService.createAnonymousUser();
        GeneratedMission generated = new GeneratedMission(
                "Phase5Oracle" + user.userId(),
                "기존 목록과 겹치지 않는 야외 협동 활동을 짧게 시도합니다 " + user.userId(),
                MissionCategory.OUTDOOR,
                2,
                15,
                1,
                1,
                2,
                2);
        MissionContentGenerator generator = new MissionContentGenerator() {
            @Override
            public boolean isAvailable() {
                return true;
            }

            @Override
            public String modelName() {
                return "phase5-oracle-test-model";
            }

            @Override
            public GeneratedMission generate(
                    UserMissionVector userVector,
                    List<Mission> existingMissions) {
                return generated;
            }
        };
        MissionLlmGenerationService generationService = new MissionLlmGenerationService(
                missionRepository, generator, new MissionSimilarityPolicy());
        UserMissionVector vector = new UserMissionVector(-1, -1, 0, 0, 5);

        assertThat(generationService.generateAtMilestone(user.userId(), 5, vector))
                .isEqualTo("CREATED");
        assertThat(generationService.generateAtMilestone(user.userId(), 5, vector))
                .isEqualTo("ALREADY_PROCESSED");
        assertThat(integer("""
                SELECT COUNT(*) FROM MISSION
                 WHERE TITLE = ? AND SOURCE_TYPE = 'LLM' AND ENABLED = 'Y'
                """, generated.title())).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject("""
                SELECT STATUS FROM MISSION_LLM_GENERATION
                 WHERE USER_ID = ? AND COMPLETION_MILESTONE = 5
                """, String.class, user.userId())).isEqualTo("COMPLETED");

        TestTransaction.flagForRollback();
        TestTransaction.end();
        assertThat(baseline()).isEqualTo(baseline);
        System.out.println("MISSION_PHASE5_LLM_ORACLE_VERIFICATION=PASS");
    }

    private long createPersonalityProfile(long userId, int completedCount) {
        Long surveyId = jdbcTemplate.queryForObject(
                "SELECT SURVEY_RESPONSE_SEQ.NEXTVAL FROM DUAL", Long.class);
        jdbcTemplate.update("""
                INSERT INTO SURVEY_RESPONSE (
                    SURVEY_ID, ACTIVITY_LEVEL, SOCIAL_ACTIVITY,
                    NOVELTY_TOLERANCE, ENERGY_LEVEL
                ) VALUES (?, 'INDOOR', 'LOW', 'LOW', 'LOW')
                """, surveyId);
        jdbcTemplate.update("""
                INSERT INTO USER_PERSONALITY_PROFILE (
                    USER_ID, PERSONALITY_CODE, ACTIVITY_SCORE, SOCIAL_SCORE,
                    NOVELTY_SCORE, PHYSICAL_ACTIVITY_SCORE,
                    COMPLETED_MISSION_COUNT, LAST_MISSION_ADAPTED_COUNT,
                    EXECUTION_STYLE, SOURCE_SURVEY_ID, ANALYSIS_VERSION
                ) VALUES (?, 'QUIET_FOCUSER', -1, -1, 0, 0, ?, 0,
                          'PLANNED', ?, 'PERSONALITY_V2')
                """, userId, completedCount, surveyId);
        return surveyId;
    }

    private void seedHistoricalCompletions(long userId, int count) {
        List<MissionSeed> missions = jdbcTemplate.query("""
                SELECT MISSION_ID, CATEGORY
                  FROM MISSION
                 WHERE ENABLED = 'Y'
                 ORDER BY MISSION_ID
                 FETCH FIRST ? ROWS ONLY
                """, (resultSet, rowNumber) -> new MissionSeed(
                        resultSet.getLong("MISSION_ID"),
                        MissionCategory.valueOf(resultSet.getString("CATEGORY"))), count);
        assertThat(missions).hasSize(count);
        LocalDate today = LocalDate.now(SEOUL);
        for (int index = 0; index < missions.size(); index++) {
            MissionSeed mission = missions.get(index);
            LocalDate serviceDate = today.minusDays(10L + count - index);
            OffsetDateTime completedAt = serviceDate.atTime(12, 0).atZone(SEOUL).toOffsetDateTime();
            Long userMissionId = jdbcTemplate.queryForObject(
                    "SELECT USER_MISSION_SEQ.NEXTVAL FROM DUAL", Long.class);
            jdbcTemplate.update("""
                    INSERT INTO USER_MISSION (
                        USER_MISSION_ID, USER_ID, MISSION_ID, STATUS,
                        AVAILABLE_TIME, SERVICE_DATE, OFFER_BATCH_ID,
                        PERSONALITY_DISTANCE, RECOMMENDATION_SCORE,
                        DAILY_SLOT_NO, SHOWN_AT, SELECTED_AT, COMPLETED_AT
                    ) VALUES (?, ?, ?, 'COMPLETED', 'SHORT', ?, ?,
                              0.5, 0.5, 1, ?, ?, ?)
                    """,
                    userMissionId,
                    userId,
                    mission.missionId(),
                    Date.valueOf(serviceDate),
                    "phase5-history-" + userId + "-" + index,
                    completedAt,
                    completedAt,
                    completedAt);
            Long statusLogId = jdbcTemplate.queryForObject(
                    "SELECT MISSION_STATUS_LOG_SEQ.NEXTVAL FROM DUAL", Long.class);
            jdbcTemplate.update("""
                    INSERT INTO MISSION_STATUS_LOG (
                        STATUS_LOG_ID, USER_ID, MISSION_ID, USER_MISSION_ID,
                        CATEGORY, PREVIOUS_STATUS, STATUS, CHANGE_REASON, OCCURRED_AT
                    ) VALUES (?, ?, ?, ?, ?, 'SELECTED', 'COMPLETED',
                              'PHASE5_TEST_HISTORY', ?)
                    """,
                    statusLogId,
                    userId,
                    mission.missionId(),
                    userMissionId,
                    mission.category().name(),
                    completedAt);
            completionRepository.incrementCategory(userId, mission.category(), completedAt);
        }
    }

    private int profileCount(long userId) {
        return integer("""
                SELECT COMPLETED_MISSION_COUNT FROM USER_PERSONALITY_PROFILE
                 WHERE USER_ID = ?
                """, userId);
    }

    private int lastAdaptedCount(long userId) {
        return integer("""
                SELECT LAST_MISSION_ADAPTED_COUNT FROM USER_PERSONALITY_PROFILE
                 WHERE USER_ID = ?
                """, userId);
    }

    private int activityScore(long userId) {
        return integer("SELECT ACTIVITY_SCORE FROM USER_PERSONALITY_PROFILE WHERE USER_ID = ?", userId);
    }

    private int socialScore(long userId) {
        return integer("SELECT SOCIAL_SCORE FROM USER_PERSONALITY_PROFILE WHERE USER_ID = ?", userId);
    }

    private int physicalActivityScore(long userId) {
        return integer("""
                SELECT PHYSICAL_ACTIVITY_SCORE FROM USER_PERSONALITY_PROFILE
                 WHERE USER_ID = ?
                """, userId);
    }

    private int noveltyScore(long userId) {
        return integer("SELECT NOVELTY_SCORE FROM USER_PERSONALITY_PROFILE WHERE USER_ID = ?", userId);
    }

    private String personalityCode(long userId) {
        return jdbcTemplate.queryForObject(
                "SELECT PERSONALITY_CODE FROM USER_PERSONALITY_PROFILE WHERE USER_ID = ?",
                String.class,
                userId);
    }

    private int categoryTotal(long userId) {
        return integer("""
                SELECT COALESCE(SUM(COMPLETED_COUNT), 0)
                  FROM USER_MISSION_CATEGORY_STAT
                 WHERE USER_ID = ?
                """, userId);
    }

    private int generationCount(long userId, int milestone) {
        return integer("""
                SELECT COUNT(*) FROM MISSION_LLM_GENERATION
                 WHERE USER_ID = ? AND COMPLETION_MILESTONE = ?
                """, userId, milestone);
    }

    private int completedLogCount(long userMissionId) {
        return integer("""
                SELECT COUNT(*) FROM MISSION_STATUS_LOG
                 WHERE USER_MISSION_ID = ? AND STATUS = 'COMPLETED'
                """, userMissionId);
    }

    private String userMissionStatus(long userMissionId) {
        return jdbcTemplate.queryForObject(
                "SELECT STATUS FROM USER_MISSION WHERE USER_MISSION_ID = ?",
                String.class,
                userMissionId);
    }

    private String expectedPersonalityCode(int indoorOutdoor, int social) {
        return switch (indoorOutdoor + ":" + social) {
            case "-1:-1" -> "QUIET_FOCUSER";
            case "-1:0" -> "COZY_EXPLORER";
            case "-1:1" -> "WARM_HOST";
            case "0:-1" -> "FLEXIBLE_INDEPENDENT";
            case "0:0" -> "BALANCED_COORDINATOR";
            case "0:1" -> "OPEN_CONNECTOR";
            case "1:-1" -> "SOLO_EXPLORER";
            case "1:0" -> "FREE_PIONEER";
            case "1:1" -> "ACTIVE_CONNECTOR";
            default -> throw new IllegalStateException("Unexpected personality vector.");
        };
    }

    private int integer(String sql, Object... parameters) {
        Integer value = jdbcTemplate.queryForObject(sql, Integer.class, parameters);
        return value == null ? 0 : value;
    }

    private Baseline baseline() {
        return new Baseline(
                integer("SELECT COUNT(*) FROM NOVELTY_USER"),
                integer("SELECT COUNT(*) FROM USER_MISSION"),
                integer("SELECT COUNT(*) FROM MISSION_STATUS_LOG"),
                integer("SELECT COUNT(*) FROM USER_PERSONALITY_PROFILE"),
                integer("SELECT COUNT(*) FROM USER_MISSION_CATEGORY_STAT"),
                integer("SELECT COUNT(*) FROM MISSION_LLM_GENERATION"),
                integer("SELECT COUNT(*) FROM MISSION"));
    }

    private record MissionSeed(long missionId, MissionCategory category) {
    }

    private record Baseline(
            int users,
            int userMissions,
            int statusLogs,
            int profiles,
            int categoryStats,
            int llmGenerations,
            int missions) {
    }
}
