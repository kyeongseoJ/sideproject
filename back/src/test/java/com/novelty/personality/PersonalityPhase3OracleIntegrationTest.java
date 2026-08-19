package com.novelty.personality;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.when;

import java.util.List;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;

import com.novelty.user.UserService;

@EnabledIfEnvironmentVariable(named = "RUN_ORACLE_INTEGRATION", matches = "true")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE)
class PersonalityPhase3OracleIntegrationTest {

    private static final long USER_ID = -930_001L;
    private static final String USER_KEY = "phase3-integration-user-key";
    private static final String INITIAL_SUBMISSION = "3b7aa3c1-17cb-4ee8-8fab-9785066785cf";
    private static final String REANALYSIS_SUBMISSION = "558be5b4-6e89-46d3-8661-6a2e40782247";
    private static final String ROLLBACK_SUBMISSION = "de7ce75c-4bf2-4d61-898b-098ccf4d88d7";

    @Autowired
    private PersonalityService service;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @MockitoSpyBean
    private PersonalityRepository repository;

    @MockitoBean
    private UserService userService;

    @BeforeEach
    void setUpFixture() {
        cleanupFixture();
        jdbcTemplate.update("""
                INSERT INTO NOVELTY_USER (
                    USER_ID, USER_KEY_HASH, NICKNAME, NICKNAME_NORMALIZED
                ) VALUES (?, ?, ?, ?)
                """,
                USER_ID,
                "phase3-test-user-key-hash-000000000000000000000000000000000000",
                "PHASE3T01",
                "PHASE3T01");
        when(userService.requireUserId(USER_KEY)).thenReturn(USER_ID);
    }

    @AfterEach
    void cleanupFixture() {
        jdbcTemplate.update("DELETE FROM USER_PROFILE_INTEREST WHERE USER_ID = ?", USER_ID);
        jdbcTemplate.update("DELETE FROM USER_PERSONALITY_PROFILE WHERE USER_ID = ?", USER_ID);
        jdbcTemplate.update("""
                DELETE FROM SURVEY_INTEREST
                 WHERE SURVEY_ID IN (
                    SELECT SURVEY_ID FROM SURVEY_RESPONSE WHERE USER_ID = ?
                 )
                """, USER_ID);
        jdbcTemplate.update("DELETE FROM SURVEY_RESPONSE WHERE USER_ID = ?", USER_ID);
        jdbcTemplate.update("DELETE FROM NOVELTY_USER WHERE USER_ID = ?", USER_ID);
    }

    @Test
    @Timeout(60)
    void persistsRetriesReanalyzesAndRollsBackAtomically() {
        assertThatThrownBy(() -> service.analyze(
                USER_KEY,
                request(REANALYSIS_SUBMISSION, AnalysisMode.REANALYSIS, IndoorOutdoor.OUTDOOR)))
                .isInstanceOf(PersonalityNotAnalyzedException.class);
        assertThat(responseCount()).isZero();

        PersonalitySubmissionResult initial = service.analyze(
                USER_KEY,
                request(INITIAL_SUBMISSION, AnalysisMode.INITIAL, IndoorOutdoor.INDOOR));

        assertThat(initial.created()).isTrue();
        assertThat(initial.response().personality().typeCode()).isEqualTo("QUIET_FOCUSER");
        assertThat(responseCount()).isEqualTo(1);
        assertThat(profileCount()).isEqualTo(1);
        assertThat(profileInterestCount()).isEqualTo(2);
        assertThat(submissionInterestCount(initial.response().analysisId())).isEqualTo(2);
        assertThat(jdbcTemplate.queryForObject("""
                SELECT COUNT(*)
                  FROM SURVEY_RESPONSE
                 WHERE SURVEY_ID = ?
                   AND ENERGY_LEVEL IS NULL
                   AND ANALYSIS_MODE = 'INITIAL'
                   AND ANALYSIS_VERSION = 'PERSONALITY_V2'
                """, Integer.class, initial.response().analysisId())).isEqualTo(1);

        PersonalitySubmissionResult retry = service.analyze(
                USER_KEY,
                request(INITIAL_SUBMISSION, AnalysisMode.INITIAL, IndoorOutdoor.INDOOR));

        assertThat(retry.created()).isFalse();
        assertThat(retry.response().analysisId()).isEqualTo(initial.response().analysisId());
        assertThat(responseCount()).isEqualTo(1);

        assertThatThrownBy(() -> service.analyze(
                USER_KEY,
                request(INITIAL_SUBMISSION, AnalysisMode.INITIAL, IndoorOutdoor.OUTDOOR)))
                .isInstanceOf(SubmissionKeyConflictException.class);
        assertThatThrownBy(() -> service.analyze(
                USER_KEY,
                request(REANALYSIS_SUBMISSION, AnalysisMode.INITIAL, IndoorOutdoor.OUTDOOR)))
                .isInstanceOf(PersonalityAlreadyAnalyzedException.class);
        assertThat(responseCount()).isEqualTo(1);

        PersonalitySubmissionResult reanalysis = service.analyze(
                USER_KEY,
                request(REANALYSIS_SUBMISSION, AnalysisMode.REANALYSIS, IndoorOutdoor.OUTDOOR));

        assertThat(reanalysis.created()).isTrue();
        assertThat(reanalysis.response().personality().typeCode()).isEqualTo("SOLO_EXPLORER");
        assertThat(responseCount()).isEqualTo(2);
        assertThat(profileCount()).isEqualTo(1);
        assertThat(repository.findCurrentProfile(USER_ID)).hasValueSatisfying(profile -> {
            assertThat(profile.typeCode()).isEqualTo("SOLO_EXPLORER");
            assertThat(profile.indoorOutdoor()).isEqualTo(IndoorOutdoor.OUTDOOR);
            assertThat(profile.interests()).containsExactly(Interest.CREATIVE, Interest.LEARNING);
        });

        long sourceBeforeFailure = currentSourceSurveyId();
        doThrow(new DataAccessResourceFailureException("forced after profile update"))
                .when(repository)
                .replaceProfileInterests(eq(USER_ID), anyList());

        assertThatThrownBy(() -> service.analyze(
                USER_KEY,
                request(ROLLBACK_SUBMISSION, AnalysisMode.REANALYSIS, IndoorOutdoor.MIXED)))
                .isInstanceOf(DataAccessResourceFailureException.class);

        assertThat(responseCount()).isEqualTo(2);
        assertThat(profileCount()).isEqualTo(1);
        assertThat(currentSourceSurveyId()).isEqualTo(sourceBeforeFailure);
        assertThat(jdbcTemplate.queryForObject("""
                SELECT PERSONALITY_CODE
                  FROM USER_PERSONALITY_PROFILE
                 WHERE USER_ID = ?
                """, String.class, USER_ID)).isEqualTo("SOLO_EXPLORER");

        System.out.println("PHASE3_ORACLE_VERIFICATION=PASS");
    }

    private PersonalityAnalysisRequest request(
            String submissionKey,
            AnalysisMode mode,
            IndoorOutdoor indoorOutdoor) {
        return new PersonalityAnalysisRequest(
                submissionKey,
                mode,
                indoorOutdoor,
                SocialLevel.LOW,
                PhysicalActivityLevel.MEDIUM,
                NoveltyLevel.HIGH,
                List.of(Interest.LEARNING, Interest.CREATIVE),
                ExecutionStyle.FLEXIBLE);
    }

    private int responseCount() {
        return jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM SURVEY_RESPONSE WHERE USER_ID = ?",
                Integer.class,
                USER_ID);
    }

    private int profileCount() {
        return jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM USER_PERSONALITY_PROFILE WHERE USER_ID = ?",
                Integer.class,
                USER_ID);
    }

    private int profileInterestCount() {
        return jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM USER_PROFILE_INTEREST WHERE USER_ID = ?",
                Integer.class,
                USER_ID);
    }

    private int submissionInterestCount(long analysisId) {
        return jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM SURVEY_INTEREST WHERE SURVEY_ID = ?",
                Integer.class,
                analysisId);
    }

    private long currentSourceSurveyId() {
        return jdbcTemplate.queryForObject(
                "SELECT SOURCE_SURVEY_ID FROM USER_PERSONALITY_PROFILE WHERE USER_ID = ?",
                Long.class,
                USER_ID);
    }
}
