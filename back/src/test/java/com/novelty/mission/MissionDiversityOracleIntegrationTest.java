package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.Rollback;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@EnabledIfEnvironmentVariable(named = "RUN_ORACLE_INTEGRATION", matches = "true")
@Transactional
@Rollback
class MissionDiversityOracleIntegrationTest {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private MissionRepository missionRepository;

    @Test
    void readsDiversityMetadataAndEnforcesDatabaseConstraints() {
        List<String> expectedColumns = List.of(
                "ACTION_TYPE", "CREATIVITY_LEVEL", "UNPREDICTABILITY_LEVEL",
                "COMFORT_ZONE_DISTANCE", "COST_LEVEL", "TAGS");
        Integer columnCount = jdbcTemplate.queryForObject("""
                SELECT COUNT(*)
                  FROM USER_TAB_COLUMNS
                 WHERE TABLE_NAME = 'MISSION'
                   AND COLUMN_NAME IN (
                       'ACTION_TYPE', 'CREATIVITY_LEVEL', 'UNPREDICTABILITY_LEVEL',
                       'COMFORT_ZONE_DISTANCE', 'COST_LEVEL', 'TAGS'
                   )
                """, Integer.class);
        assertThat(columnCount).isEqualTo(expectedColumns.size());

        List<Mission> missions = missionRepository.findAllEnabled();
        assertThat(missions).isNotEmpty().allSatisfy(mission -> {
            assertThat(mission.actionType()).isNotNull();
            assertThat(mission.tags()).isNotEmpty();
            assertThat(mission.creativityLevel()).isBetween(0, 2);
            assertThat(mission.unpredictabilityLevel()).isBetween(0, 2);
            assertThat(mission.comfortZoneDistance()).isBetween(0, 2);
            assertThat(mission.costLevel()).isBetween(0, 2);
        });
        assertThat(missions.stream().map(Mission::actionType).distinct().count())
                .isGreaterThanOrEqualTo(5);

        long missionId = missions.getFirst().id();
        assertThatThrownBy(() -> jdbcTemplate.update(
                "UPDATE MISSION SET CREATIVITY_LEVEL = 3 WHERE MISSION_ID = ?", missionId))
                .isInstanceOf(DataIntegrityViolationException.class);
        assertThatThrownBy(() -> jdbcTemplate.update(
                "UPDATE MISSION SET TAGS = 'INVALID TAG' WHERE MISSION_ID = ?", missionId))
                .isInstanceOf(DataIntegrityViolationException.class);
        assertThatThrownBy(() -> jdbcTemplate.update(
                "UPDATE MISSION SET TAGS = 'A,B,C,D,E,F,G,H,I,J,K' WHERE MISSION_ID = ?", missionId))
                .isInstanceOf(DataIntegrityViolationException.class);
        assertThatThrownBy(() -> jdbcTemplate.update(
                "UPDATE MISSION SET TAGS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ123456' WHERE MISSION_ID = ?",
                missionId))
                .isInstanceOf(DataIntegrityViolationException.class);
    }
}
