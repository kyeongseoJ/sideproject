package com.novelty.mission;

import java.time.OffsetDateTime;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class MissionStatusLogRepository {

    private static final String NEXT_LOG_ID_SQL =
            "SELECT nextval('mission_status_log_seq')";

    private final JdbcTemplate jdbcTemplate;

    public MissionStatusLogRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public long append(
            long userId,
            long missionId,
            Long userMissionId,
            String category,
            MissionStatus previousStatus,
            MissionStatus status,
            String changeReason,
            OffsetDateTime occurredAt) {
        Long logId = jdbcTemplate.queryForObject(NEXT_LOG_ID_SQL, Long.class);
        if (logId == null) {
            throw new IllegalStateException("PostgreSQL did not return a mission status log ID.");
        }

        jdbcTemplate.update("""
                INSERT INTO MISSION_STATUS_LOG (
                    STATUS_LOG_ID, USER_ID, MISSION_ID, USER_MISSION_ID,
                    CATEGORY, PREVIOUS_STATUS, STATUS, CHANGE_REASON, OCCURRED_AT
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                logId,
                userId,
                missionId,
                userMissionId,
                category,
                previousStatus == null ? null : previousStatus.name(),
                status.name(),
                changeReason,
                occurredAt);
        return logId;
    }

    public List<MissionStatusEvent> findAll(long userId) {
        return jdbcTemplate.query("""
                SELECT log_row.MISSION_ID, log_row.CATEGORY, log_row.USER_MISSION_ID,
                       log_row.STATUS, log_row.OCCURRED_AT,
                       mission_row.TITLE, mission_row.DESCRIPTION,
                       mission_row.DIFFICULTY, mission_row.ESTIMATED_MINUTES,
                       mission_row.INDOOR_OUTDOOR, mission_row.SOCIAL_LEVEL,
                       mission_row.ACTIVITY_LEVEL, mission_row.NOVELTY_LEVEL,
                       mission_row.ACTION_TYPE, mission_row.CREATIVITY_LEVEL,
                       mission_row.UNPREDICTABILITY_LEVEL,
                       mission_row.COMFORT_ZONE_DISTANCE, mission_row.COST_LEVEL,
                       mission_row.TAGS, mission_row.ENABLED, mission_row.SOURCE_TYPE
                  FROM MISSION_STATUS_LOG log_row
                  JOIN MISSION mission_row ON mission_row.MISSION_ID = log_row.MISSION_ID
                 WHERE log_row.USER_ID = ?
                 ORDER BY log_row.OCCURRED_AT DESC, log_row.STATUS_LOG_ID DESC
                """,
                (resultSet, rowNumber) -> {
                    long missionId = resultSet.getLong("MISSION_ID");
                    MissionCategory category = MissionCategory.valueOf(
                            resultSet.getString("CATEGORY"));
                    long rawUserMissionId = resultSet.getLong("USER_MISSION_ID");
                    Long userMissionId = resultSet.wasNull() ? null : rawUserMissionId;
                    Mission mission = new Mission(
                            missionId,
                            resultSet.getString("TITLE"),
                            resultSet.getString("DESCRIPTION"),
                            category,
                            resultSet.getInt("DIFFICULTY"),
                            resultSet.getInt("ESTIMATED_MINUTES"),
                            resultSet.getInt("INDOOR_OUTDOOR"),
                            resultSet.getInt("SOCIAL_LEVEL"),
                            resultSet.getInt("ACTIVITY_LEVEL"),
                            resultSet.getInt("NOVELTY_LEVEL"),
                            MissionActionType.valueOf(resultSet.getString("ACTION_TYPE")),
                            resultSet.getInt("CREATIVITY_LEVEL"),
                            resultSet.getInt("UNPREDICTABILITY_LEVEL"),
                            resultSet.getInt("COMFORT_ZONE_DISTANCE"),
                            resultSet.getInt("COST_LEVEL"),
                            MissionRepository.parseTags(resultSet.getString("TAGS")),
                            "Y".equals(resultSet.getString("ENABLED")),
                            MissionSourceType.valueOf(resultSet.getString("SOURCE_TYPE")));
                    return new MissionStatusEvent(
                            missionId,
                            category.name(),
                            mission,
                            userMissionId,
                            MissionStatus.valueOf(resultSet.getString("STATUS")),
                            resultSet.getObject("OCCURRED_AT", OffsetDateTime.class));
                },
                userId);
    }

}
