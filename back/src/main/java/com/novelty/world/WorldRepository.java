package com.novelty.world;

import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import com.novelty.mission.MissionCategory;

@Repository
public class WorldRepository {

    private final JdbcTemplate jdbcTemplate;

    public WorldRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<WorldObjectProgressResponse> findSnapshot(long userId) {
        return jdbcTemplate.query("""
                SELECT object.OBJECT_CODE, object.CATEGORY, object.DISPLAY_NAME,
                       COALESCE(progress.CURRENT_LEVEL, 1) CURRENT_LEVEL,
                       COALESCE(progress.EXPERIENCE, 0) EXPERIENCE,
                       object.MAX_LEVEL,
                       (SELECT MIN(levels.REQUIRED_EXPERIENCE)
                          FROM WORLD_OBJECT_LEVEL levels
                         WHERE levels.WORLD_OBJECT_ID = object.WORLD_OBJECT_ID
                           AND levels.OBJECT_LEVEL > COALESCE(progress.CURRENT_LEVEL, 1)) NEXT_EXP
                  FROM WORLD_OBJECT object
                  LEFT JOIN USER_WORLD_OBJECT progress
                    ON progress.WORLD_OBJECT_ID = object.WORLD_OBJECT_ID
                   AND progress.USER_ID = ?
                 WHERE object.ENABLED = 'Y'
                 ORDER BY object.CATEGORY
                """, (resultSet, rowNumber) -> new WorldObjectProgressResponse(
                resultSet.getString("OBJECT_CODE"),
                resultSet.getString("CATEGORY"),
                resultSet.getString("DISPLAY_NAME"),
                resultSet.getInt("CURRENT_LEVEL"),
                resultSet.getInt("EXPERIENCE"),
                resultSet.getObject("NEXT_EXP", Integer.class),
                resultSet.getInt("MAX_LEVEL")), userId);
    }

    Optional<WorldObjectDefinition> findDefinition(MissionCategory category) {
        return jdbcTemplate.query("""
                SELECT WORLD_OBJECT_ID, OBJECT_CODE, CATEGORY, MAX_LEVEL
                  FROM WORLD_OBJECT
                 WHERE CATEGORY = ? AND ENABLED = 'Y'
                """, (resultSet, rowNumber) -> new WorldObjectDefinition(
                resultSet.getLong("WORLD_OBJECT_ID"),
                resultSet.getString("OBJECT_CODE"),
                MissionCategory.valueOf(resultSet.getString("CATEGORY")),
                resultSet.getInt("MAX_LEVEL")), category.name()).stream().findFirst();
    }

    Optional<UserWorldProgress> findProgressForUpdate(long userId, long worldObjectId) {
        return jdbcTemplate.query("""
                SELECT EXPERIENCE, CURRENT_LEVEL
                  FROM USER_WORLD_OBJECT
                 WHERE USER_ID = ? AND WORLD_OBJECT_ID = ?
                   FOR UPDATE
                """, (resultSet, rowNumber) -> new UserWorldProgress(
                resultSet.getInt("EXPERIENCE"),
                resultSet.getInt("CURRENT_LEVEL")), userId, worldObjectId).stream().findFirst();
    }

    int findLevel(long worldObjectId, int exp) {
        Integer level = jdbcTemplate.queryForObject("""
                SELECT MAX(OBJECT_LEVEL)
                  FROM WORLD_OBJECT_LEVEL
                 WHERE WORLD_OBJECT_ID = ? AND REQUIRED_EXPERIENCE <= ?
                """, Integer.class, worldObjectId, exp);
        if (level == null) {
            throw new IllegalStateException("World level definition is missing.");
        }
        return level;
    }

    Integer findNextRequiredExp(long worldObjectId, int level) {
        return jdbcTemplate.queryForObject("""
                SELECT MIN(REQUIRED_EXPERIENCE)
                  FROM WORLD_OBJECT_LEVEL
                 WHERE WORLD_OBJECT_ID = ? AND OBJECT_LEVEL > ?
                """, Integer.class, worldObjectId, level);
    }

    void upsertProgress(long userId, long worldObjectId, int exp, int level) {
        int updated = jdbcTemplate.update("""
                INSERT INTO USER_WORLD_OBJECT (
                    USER_ID, WORLD_OBJECT_ID, EXPERIENCE, CURRENT_LEVEL
                ) VALUES (?, ?, ?, ?)
                ON CONFLICT (USER_ID, WORLD_OBJECT_ID) DO UPDATE SET
                    EXPERIENCE = EXCLUDED.EXPERIENCE,
                    CURRENT_LEVEL = EXCLUDED.CURRENT_LEVEL,
                    UPDATED_AT = CURRENT_TIMESTAMP
                """, userId, worldObjectId, exp, level);
        if (updated != 1) {
            throw new IllegalStateException("Unexpected world progress update count.");
        }
    }

    record WorldObjectDefinition(
            long id,
            String objectCode,
            MissionCategory category,
            int maxLevel) {
    }

    record UserWorldProgress(int exp, int level) {
    }
}
