package com.novelty.mission;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.OptionalDouble;
import java.util.Random;
import java.util.stream.Collectors;

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
        assertThat(missions).hasSize(200).allSatisfy(mission -> {
            assertThat(mission.actionType()).isNotNull();
            assertThat(mission.tags()).isNotEmpty();
            assertThat(mission.creativityLevel()).isBetween(0, 2);
            assertThat(mission.unpredictabilityLevel()).isBetween(0, 2);
            assertThat(mission.comfortZoneDistance()).isBetween(0, 2);
            assertThat(mission.costLevel()).isBetween(0, 2);
        });
        assertThat(missions.stream().map(Mission::actionType).distinct().count())
                .isGreaterThanOrEqualTo(5);
        assertThat(missions.stream().collect(Collectors.groupingBy(
                Mission::category, Collectors.counting())))
                .containsExactlyInAnyOrderEntriesOf(Map.of(
                        MissionCategory.MOVEMENT, 26L,
                        MissionCategory.CREATIVE, 26L,
                        MissionCategory.FOOD, 26L,
                        MissionCategory.LEARNING, 26L,
                        MissionCategory.SOCIAL, 24L,
                        MissionCategory.OUTDOOR, 24L,
                        MissionCategory.ORGANIZING, 24L,
                        MissionCategory.CULTURE, 24L));
        assertThat(jdbcTemplate.queryForObject("""
                SELECT COUNT(*)
                  FROM MISSION
                 WHERE TITLE = ?
                   AND TAGS = ?
                   AND ENABLED = 'Y'
                """, Integer.class,
                "평소 사용하지 않던 스트레칭 동작 세 가지 해보기",
                "M001,스트레칭,몸,변화"))
                .isOne();

        long missionId = missions.stream()
                .filter(mission -> mission.tags().contains("M001"))
                .findFirst()
                .orElseThrow()
                .id();
        assertThat(jdbcTemplate.update(
                "UPDATE MISSION SET TAGS = 'M001,스트레칭,몸' WHERE MISSION_ID = ?", missionId))
                .isOne();
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

    @Test
    void suppliesThreeChoicesEveryDayForThirtyDays() {
        List<Mission> missions = missionRepository.findAllEnabled();
        List<MissionStatusEvent> history = new ArrayList<>();
        Map<MissionCategory, Integer> completionCounts =
                new EnumMap<>(MissionCategory.class);
        UserMissionVector userVector = new UserMissionVector(-1, -1, 0, 0, 30);
        LocalDate firstDate = LocalDate.of(2026, 8, 1);
        ZoneId serviceZone = ZoneId.of("Asia/Seoul");
        Random random = new Random(260801L);

        for (int day = 0; day < 30; day++) {
            LocalDate serviceDate = firstDate.plusDays(day);
            Clock clock = Clock.fixed(serviceDate.atStartOfDay(serviceZone).toInstant(), serviceZone);
            MissionRecommendationPolicy policy = new MissionRecommendationPolicy(
                    clock, (left, right) -> OptionalDouble.empty());

            List<MissionRecommendation> recommendations = policy.recommend(
                    missions, userVector, AvailableTime.LONG,
                    completionCounts, history, random);

            assertThat(recommendations)
                    .as("day %s recommendations", day + 1)
                    .hasSize(3);

            OffsetDateTime occurredAt =
                    serviceDate.atTime(12, 0).atZone(serviceZone).toOffsetDateTime();
            long dailyLogBase = (day + 1L) * 10L;
            for (int index = 0; index < recommendations.size(); index++) {
                Mission shown = recommendations.get(index).mission();
                history.add(new MissionStatusEvent(
                        shown.id(), shown.category().name(), shown,
                        dailyLogBase + index, MissionStatus.SHOWN, occurredAt));
            }

            Mission completed = recommendations.getFirst().mission();
            history.add(new MissionStatusEvent(
                    completed.id(), completed.category().name(), completed,
                    dailyLogBase, MissionStatus.COMPLETED, occurredAt.plusMinutes(1)));
            completionCounts.merge(completed.category(), 1, Integer::sum);
        }
    }
}
