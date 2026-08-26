-- Mission recommendations no longer depend on user-selected duration or count.
-- Existing user_mission rows and their status history remain intact.
ALTER TABLE user_mission
    DROP COLUMN IF EXISTS available_time;

DROP TABLE IF EXISTS user_mission_setting;
