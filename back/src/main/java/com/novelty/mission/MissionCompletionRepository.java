package com.novelty.mission;

import java.time.OffsetDateTime;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class MissionCompletionRepository {

    private final JdbcTemplate jdbcTemplate;

    public MissionCompletionRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void incrementCategory(
            long userId,
            MissionCategory category,
            OffsetDateTime completedAt) {
        int updated = jdbcTemplate.update("""
                INSERT INTO USER_MISSION_CATEGORY_STAT (
                    USER_ID, CATEGORY, COMPLETED_COUNT, LAST_COMPLETED_AT, UPDATED_AT
                ) VALUES (?, ?, 1, ?, ?)
                ON CONFLICT (USER_ID, CATEGORY) DO UPDATE SET
                    COMPLETED_COUNT = USER_MISSION_CATEGORY_STAT.COMPLETED_COUNT + 1,
                    LAST_COMPLETED_AT = EXCLUDED.LAST_COMPLETED_AT,
                    UPDATED_AT = EXCLUDED.UPDATED_AT
                """,
                userId,
                category.name(),
                completedAt,
                completedAt);
        if (updated != 1) {
            throw new IllegalStateException("Unexpected mission category update count.");
        }
    }

    public MissionSummaryResponse findSummary(long userId) {
        ProfileSummary profile = jdbcTemplate.query("""
                SELECT COMPLETED_MISSION_COUNT,
                       LAST_MISSION_ADAPTED_COUNT,
                       PERSONALITY_CODE
                  FROM USER_PERSONALITY_PROFILE
                 WHERE USER_ID = ?
                """, (resultSet, rowNumber) -> new ProfileSummary(
                        resultSet.getInt("COMPLETED_MISSION_COUNT"),
                        resultSet.getInt("LAST_MISSION_ADAPTED_COUNT"),
                        resultSet.getString("PERSONALITY_CODE")), userId)
                .stream()
                .findFirst()
                .orElseThrow(PersonalityRequiredException::new);

        List<MissionCategoryStatResponse> categoryStats = jdbcTemplate.query("""
                SELECT CATEGORY, COMPLETED_COUNT, LAST_COMPLETED_AT
                  FROM USER_MISSION_CATEGORY_STAT
                 WHERE USER_ID = ?
                 ORDER BY COMPLETED_COUNT DESC, CATEGORY
                """, (resultSet, rowNumber) -> new MissionCategoryStatResponse(
                        MissionCategory.valueOf(resultSet.getString("CATEGORY")),
                        resultSet.getInt("COMPLETED_COUNT"),
                        resultSet.getObject("LAST_COMPLETED_AT", OffsetDateTime.class)),
                userId);
        return new MissionSummaryResponse(
                profile.completedMissionCount(),
                profile.lastPersonalityAdaptedCount(),
                profile.personalityCode(),
                categoryStats);
    }

    private record ProfileSummary(
            int completedMissionCount,
            int lastPersonalityAdaptedCount,
            String personalityCode) {
    }
}
