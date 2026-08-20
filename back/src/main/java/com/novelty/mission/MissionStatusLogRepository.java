package com.novelty.mission;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class MissionStatusLogRepository {

    private static final String NEXT_LOG_ID_SQL =
            "SELECT MISSION_STATUS_LOG_SEQ.NEXTVAL FROM DUAL";

    private static final String FIND_HISTORY_SQL = """
            SELECT MISSION_ID, CATEGORY, STATUS, OCCURRED_AT
            FROM MISSION_STATUS_LOG
            WHERE USER_ID = ?
              AND OCCURRED_AT >= ?
            ORDER BY OCCURRED_AT DESC, STATUS_LOG_ID DESC
            """;

    private final JdbcTemplate jdbcTemplate;

    public MissionStatusLogRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public long append(
            long userId,
            long missionId,
            String category,
            MissionStatus status,
            OffsetDateTime occurredAt) {
        return append(userId, missionId, null, category, null, status, null, occurredAt);
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
            throw new IllegalStateException("Oracle did not return a mission status log ID.");
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

    public List<MissionStatusEvent> findSince(long userId, OffsetDateTime since) {
        return jdbcTemplate.query(
                FIND_HISTORY_SQL,
                (resultSet, rowNumber) -> new MissionStatusEvent(
                        resultSet.getLong("MISSION_ID"),
                        resultSet.getString("CATEGORY"),
                        MissionStatus.valueOf(resultSet.getString("STATUS")),
                        resultSet.getObject("OCCURRED_AT", OffsetDateTime.class)),
                userId,
                since);
    }

    public List<MissionStatusEvent> findAll(long userId) {
        return jdbcTemplate.query("""
                SELECT MISSION_ID, CATEGORY, STATUS, OCCURRED_AT
                  FROM MISSION_STATUS_LOG
                 WHERE USER_ID = ?
                 ORDER BY OCCURRED_AT DESC, STATUS_LOG_ID DESC
                """,
                (resultSet, rowNumber) -> new MissionStatusEvent(
                        resultSet.getLong("MISSION_ID"),
                        resultSet.getString("CATEGORY"),
                        MissionStatus.valueOf(resultSet.getString("STATUS")),
                        resultSet.getObject("OCCURRED_AT", OffsetDateTime.class)),
                userId);
    }

    public Optional<MissionStatus> findLatestStatus(long userId, long missionId) {
        return jdbcTemplate.query("""
                SELECT STATUS
                  FROM (
                        SELECT STATUS
                          FROM MISSION_STATUS_LOG
                         WHERE USER_ID = ? AND MISSION_ID = ?
                         ORDER BY OCCURRED_AT DESC, STATUS_LOG_ID DESC
                  )
                 WHERE ROWNUM = 1
                """,
                (resultSet, rowNumber) -> MissionStatus.valueOf(resultSet.getString("STATUS")),
                userId,
                missionId).stream().findFirst();
    }
}
