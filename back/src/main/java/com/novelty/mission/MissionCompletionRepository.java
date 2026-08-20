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
                MERGE INTO USER_MISSION_CATEGORY_STAT target
                USING (SELECT ? USER_ID, ? CATEGORY FROM DUAL) source
                   ON (target.USER_ID = source.USER_ID
                       AND target.CATEGORY = source.CATEGORY)
                 WHEN MATCHED THEN UPDATE SET
                      target.COMPLETED_COUNT = target.COMPLETED_COUNT + 1,
                      target.LAST_COMPLETED_AT = ?,
                      target.UPDATED_AT = ?
                 WHEN NOT MATCHED THEN INSERT (
                      USER_ID, CATEGORY, COMPLETED_COUNT,
                      LAST_COMPLETED_AT, UPDATED_AT
                 ) VALUES (
                      source.USER_ID, source.CATEGORY, 1, ?, ?
                 )
                """,
                userId,
                category.name(),
                completedAt,
                completedAt,
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
