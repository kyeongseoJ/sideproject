package com.novelty.mission;

import java.sql.Date;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.HashSet;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class UserMissionRepository {

    private final JdbcTemplate jdbcTemplate;

    public UserMissionRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void lockUser(long userId) {
        jdbcTemplate.queryForObject(
                "SELECT USER_ID FROM NOVELTY_USER WHERE USER_ID = ? FOR UPDATE",
                Long.class,
                userId);
    }

    public Map<MissionCategory, Integer> findCategoryCompletionCounts(long userId) {
        Map<MissionCategory, Integer> counts = new EnumMap<>(MissionCategory.class);
        List<CategoryCount> rows = jdbcTemplate.query("""
                SELECT CATEGORY, COMPLETED_COUNT
                  FROM USER_MISSION_CATEGORY_STAT
                 WHERE USER_ID = ?
                """, (resultSet, rowNumber) -> new CategoryCount(
                        MissionCategory.valueOf(resultSet.getString("CATEGORY")),
                        resultSet.getInt("COMPLETED_COUNT")), userId);
        rows.forEach(row -> counts.put(row.category(), row.completedCount()));
        return Map.copyOf(counts);
    }

    public long insertRecommendation(
            long userId,
            LocalDate serviceDate,
            String offerBatchId,
            MissionRecommendation recommendation,
            OffsetDateTime shownAt) {
        Long userMissionId = jdbcTemplate.queryForObject(
                "SELECT nextval('user_mission_seq')", Long.class);
        if (userMissionId == null) {
            throw new IllegalStateException("PostgreSQL did not return a user mission ID.");
        }
        jdbcTemplate.update("""
                INSERT INTO USER_MISSION (
                    USER_MISSION_ID, USER_ID, MISSION_ID, STATUS,
                    SERVICE_DATE, OFFER_BATCH_ID, PERSONALITY_DISTANCE,
                    RECOMMENDATION_SCORE, SHOWN_AT
                ) VALUES (?, ?, ?, 'SHOWN', ?, ?, ?, ?, ?)
                """,
                userMissionId,
                userId,
                recommendation.mission().id(),
                Date.valueOf(serviceDate),
                offerBatchId,
                recommendation.personalityDistance(),
                recommendation.recommendationScore(),
                shownAt);
        return userMissionId;
    }

    public List<UserMissionResponse> findToday(long userId, LocalDate serviceDate) {
        return jdbcTemplate.query("""
                SELECT um.USER_MISSION_ID, m.MISSION_ID, m.TITLE, m.DESCRIPTION,
                       m.CATEGORY, m.DIFFICULTY, m.ESTIMATED_MINUTES,
                       m.INDOOR_OUTDOOR, m.SOCIAL_LEVEL, m.ACTIVITY_LEVEL,
                       m.NOVELTY_LEVEL, m.SOURCE_TYPE, um.PERSONALITY_DISTANCE,
                       um.RECOMMENDATION_SCORE, um.STATUS,
                       COALESCE(um.COMPLETED_AT, um.CANCELLED_AT, um.SELECTED_AT,
                                um.SHOWN_AT, um.UPDATED_AT) STATUS_AT
                  FROM USER_MISSION um
                  JOIN MISSION m ON m.MISSION_ID = um.MISSION_ID
                 WHERE um.USER_ID = ?
                   AND um.SERVICE_DATE = ?
                 ORDER BY CASE um.STATUS
                              WHEN 'SELECTED' THEN 1
                              WHEN 'COMPLETED' THEN 2
                              WHEN 'SHOWN' THEN 3
                              ELSE 4
                          END,
                          um.USER_MISSION_ID
                """, (resultSet, rowNumber) -> new UserMissionResponse(
                        resultSet.getLong("USER_MISSION_ID"),
                        resultSet.getLong("MISSION_ID"),
                        resultSet.getString("TITLE"),
                        resultSet.getString("DESCRIPTION"),
                        MissionCategory.valueOf(resultSet.getString("CATEGORY")),
                        resultSet.getInt("DIFFICULTY"),
                        resultSet.getInt("ESTIMATED_MINUTES"),
                        resultSet.getInt("INDOOR_OUTDOOR"),
                        resultSet.getInt("SOCIAL_LEVEL"),
                        resultSet.getInt("ACTIVITY_LEVEL"),
                        resultSet.getInt("NOVELTY_LEVEL"),
                        MissionSourceType.valueOf(resultSet.getString("SOURCE_TYPE")),
                        resultSet.getDouble("PERSONALITY_DISTANCE"),
                        resultSet.getDouble("RECOMMENDATION_SCORE"),
                        MissionStatus.valueOf(resultSet.getString("STATUS")),
                        resultSet.getObject("STATUS_AT", OffsetDateTime.class)),
                userId,
                Date.valueOf(serviceDate));
    }

    public Optional<UserMissionState> findOwnedForUpdate(
            long userId,
            long userMissionId) {
        return jdbcTemplate.query("""
                SELECT um.USER_MISSION_ID, um.MISSION_ID, m.CATEGORY, m.DIFFICULTY, um.STATUS,
                       um.SERVICE_DATE, um.DAILY_SLOT_NO
                  FROM USER_MISSION um
                  JOIN MISSION m ON m.MISSION_ID = um.MISSION_ID
                 WHERE um.USER_ID = ?
                   AND um.USER_MISSION_ID = ?
                   FOR UPDATE OF um
                """, this::mapState, userId, userMissionId)
                .stream()
                .findFirst();
    }

    public List<UserMissionState> findOwnedPairForUpdate(
            long userId,
            long firstUserMissionId,
            long secondUserMissionId) {
        return jdbcTemplate.query("""
                SELECT um.USER_MISSION_ID, um.MISSION_ID, m.CATEGORY, m.DIFFICULTY, um.STATUS,
                       um.SERVICE_DATE, um.DAILY_SLOT_NO
                  FROM USER_MISSION um
                  JOIN MISSION m ON m.MISSION_ID = um.MISSION_ID
                 WHERE um.USER_ID = ?
                   AND um.USER_MISSION_ID IN (?, ?)
                 ORDER BY um.USER_MISSION_ID
                   FOR UPDATE OF um
                """, this::mapState, userId, firstUserMissionId, secondUserMissionId);
    }

    public int countOccupiedSlots(long userId, LocalDate serviceDate) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT COUNT(*)
                  FROM USER_MISSION
                 WHERE USER_ID = ?
                   AND SERVICE_DATE = ?
                   AND STATUS IN ('SELECTED', 'COMPLETED')
                """, Integer.class, userId, Date.valueOf(serviceDate));
        return count == null ? 0 : count;
    }

    public int firstAvailableSlot(
            long userId,
            LocalDate serviceDate,
            int dailyLimit) {
        Set<Integer> used = new HashSet<>(jdbcTemplate.query("""
                SELECT DAILY_SLOT_NO
                  FROM USER_MISSION
                 WHERE USER_ID = ?
                   AND SERVICE_DATE = ?
                   AND STATUS IN ('SELECTED', 'COMPLETED')
                 ORDER BY DAILY_SLOT_NO
                """, (resultSet, rowNumber) -> resultSet.getInt("DAILY_SLOT_NO"),
                userId, Date.valueOf(serviceDate)));
        for (int slot = 1; slot <= dailyLimit; slot++) {
            if (!used.contains(slot)) {
                return slot;
            }
        }
        throw new DailyLimitReachedException();
    }

    public void markSelected(
            long userMissionId,
            int slot,
            OffsetDateTime selectedAt) {
        requireSingleUpdate(jdbcTemplate.update("""
                UPDATE USER_MISSION
                   SET STATUS = 'SELECTED', DAILY_SLOT_NO = ?, SELECTED_AT = ?,
                       CANCELLED_AT = NULL, UPDATED_AT = ?
                 WHERE USER_MISSION_ID = ?
                """, slot, selectedAt, selectedAt, userMissionId));
    }

    public void markCancelled(long userMissionId, OffsetDateTime cancelledAt) {
        requireSingleUpdate(jdbcTemplate.update("""
                UPDATE USER_MISSION
                   SET STATUS = 'CANCELLED', DAILY_SLOT_NO = NULL,
                       CANCELLED_AT = ?, UPDATED_AT = ?
                 WHERE USER_MISSION_ID = ?
                """, cancelledAt, cancelledAt, userMissionId));
    }

    public void markCompleted(long userMissionId, OffsetDateTime completedAt) {
        requireSingleUpdate(jdbcTemplate.update("""
                UPDATE USER_MISSION
                   SET STATUS = 'COMPLETED', COMPLETED_AT = ?, UPDATED_AT = ?
                 WHERE USER_MISSION_ID = ?
                """, completedAt, completedAt, userMissionId));
    }

    public Optional<UserMissionResponse> findOwned(
            long userId,
            long userMissionId) {
        return jdbcTemplate.query("""
                SELECT um.USER_MISSION_ID, m.MISSION_ID, m.TITLE, m.DESCRIPTION,
                       m.CATEGORY, m.DIFFICULTY, m.ESTIMATED_MINUTES,
                       m.INDOOR_OUTDOOR, m.SOCIAL_LEVEL, m.ACTIVITY_LEVEL,
                       m.NOVELTY_LEVEL, m.SOURCE_TYPE, um.PERSONALITY_DISTANCE,
                       um.RECOMMENDATION_SCORE, um.STATUS,
                       COALESCE(um.COMPLETED_AT, um.CANCELLED_AT, um.SELECTED_AT,
                                um.SHOWN_AT, um.UPDATED_AT) STATUS_AT
                  FROM USER_MISSION um
                  JOIN MISSION m ON m.MISSION_ID = um.MISSION_ID
                 WHERE um.USER_ID = ?
                   AND um.USER_MISSION_ID = ?
                """, this::mapResponse, userId, userMissionId)
                .stream()
                .findFirst();
    }

    private UserMissionState mapState(
            java.sql.ResultSet resultSet,
            int rowNumber) throws java.sql.SQLException {
        int slot = resultSet.getInt("DAILY_SLOT_NO");
        return new UserMissionState(
                resultSet.getLong("USER_MISSION_ID"),
                resultSet.getLong("MISSION_ID"),
                MissionCategory.valueOf(resultSet.getString("CATEGORY")),
                resultSet.getInt("DIFFICULTY"),
                MissionStatus.valueOf(resultSet.getString("STATUS")),
                resultSet.getDate("SERVICE_DATE").toLocalDate(),
                resultSet.wasNull() ? null : slot);
    }

    private UserMissionResponse mapResponse(
            java.sql.ResultSet resultSet,
            int rowNumber) throws java.sql.SQLException {
        return new UserMissionResponse(
                resultSet.getLong("USER_MISSION_ID"),
                resultSet.getLong("MISSION_ID"),
                resultSet.getString("TITLE"),
                resultSet.getString("DESCRIPTION"),
                MissionCategory.valueOf(resultSet.getString("CATEGORY")),
                resultSet.getInt("DIFFICULTY"),
                resultSet.getInt("ESTIMATED_MINUTES"),
                resultSet.getInt("INDOOR_OUTDOOR"),
                resultSet.getInt("SOCIAL_LEVEL"),
                resultSet.getInt("ACTIVITY_LEVEL"),
                resultSet.getInt("NOVELTY_LEVEL"),
                MissionSourceType.valueOf(resultSet.getString("SOURCE_TYPE")),
                resultSet.getDouble("PERSONALITY_DISTANCE"),
                resultSet.getDouble("RECOMMENDATION_SCORE"),
                MissionStatus.valueOf(resultSet.getString("STATUS")),
                resultSet.getObject("STATUS_AT", OffsetDateTime.class));
    }

    private void requireSingleUpdate(int updatedRows) {
        if (updatedRows != 1) {
            throw new IllegalStateException("Unexpected user mission update count.");
        }
    }

    private record CategoryCount(MissionCategory category, int completedCount) {
    }
}
