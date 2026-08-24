-- Novelty database schema for Oracle Database 21c.
--
-- This is the authoritative database script for the project.
-- Keep back/src/main/resources/db/survey-schema.sql identical to this file.
-- Run this script while connected as the application schema owner.
-- The script is idempotent: existing objects are preserved.
--
-- Applied history
-- 2026-08-19: Added and applied the Phase 1 survey schema.
--   - SURVEY_RESPONSE_SEQ
--   - SURVEY_RESPONSE
--   - SURVEY_INTEREST
-- 2026-08-19: Verified the Phase 7 API save flow and removed verification data.
-- 2026-08-19: Added the Phase 1 anonymous user and personality profile schema.
--   - NOVELTY_USER_SEQ / NOVELTY_USER
--   - NICKNAME_BANNED_WORD_SEQ / NICKNAME_BANNED_WORD
--   - USER_PERSONALITY_PROFILE / USER_PROFILE_INTEREST
--   - SURVEY_RESPONSE user, submission, and execution-style columns
-- 2026-08-19: Added the database-level nickname banned-word trigger.
--   - TRG_NOVELTY_USER_NICKNAME_BANNED
-- 2026-08-19: Added the mission status log schema for recommendation history.
--   - MISSION_STATUS_LOG_SEQ / MISSION_STATUS_LOG
--   - GENERATED / SHOWN / SELECTED / CANCELLED / COMPLETED status constraint
-- 2026-08-19: Added the mission catalog, four-axis mission vector and LLM generation milestones.
--   - MISSION_SEQ / MISSION / MISSION_LLM_GENERATION_SEQ / MISSION_LLM_GENERATION
--   - Base mission seed data and mission completion-driven profile columns
-- 2026-08-19: Prepared the target mission-assignment and 3D world progression structure.
--   - USER_MISSION_SEQ / USER_MISSION
--   - WORLD_OBJECT_SEQ / WORLD_OBJECT / WORLD_OBJECT_LEVEL / USER_WORLD_OBJECT
--   - Oracle application is pending because the local connection failed with ORA-12638.
-- 2026-08-19: Added and applied the Personality V2 Phase 1 non-destructive migration.
--   - PHYSICAL_ACTIVITY_LEVEL / ANALYSIS_MODE / ANALYSIS_VERSION
--   - Expanded USER_PERSONALITY_PROFILE.ANALYSIS_VERSION to 24 characters
--   - Per-user submission-key uniqueness and V2 conditional required-field checks
--   - Verified idempotent re-run, 4 existing V1 responses preserved, and 0 existing profiles
-- 2026-08-19: Added and applied the Mission V1 Phase 1 non-destructive migration.
--   - USER_MISSION assignment metadata, score, service-date, state-slot constraints and indexes
--   - USER_MISSION_SETTING / USER_MISSION_CATEGORY_STAT
--   - MISSION_STATUS_LOG aggregate link and USER_PERSONALITY_PROFILE adaptation checkpoint
--   - Verified idempotent re-run, active-slot uniqueness, normal inserts, failure constraints and rollback
-- 2026-08-20: Removed duplicate USER_MISSION sequence, table, FK, and index script blocks.
--   - Logical schema is unchanged; current Oracle re-application was not performed in this maintenance task.
-- 2026-08-24: Added mission experience-diversity metadata and constraints.
--   - ACTION_TYPE / CREATIVITY_LEVEL / UNPREDICTABILITY_LEVEL
--   - COMFORT_ZONE_DISTANCE / COST_LEVEL / TAGS
--   - Existing base missions receive explicit metadata; local Oracle idempotent application completed.
--
-- Future database changes
-- Add every future CREATE, ALTER, index, constraint, and required reference-data
-- statement to this file in execution order before applying it to Oracle.
-- Add a dated history entry above whenever a change is applied.

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_sequences
     WHERE sequence_name = 'SURVEY_RESPONSE_SEQ';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE SEQUENCE SURVEY_RESPONSE_SEQ
                START WITH 1
                INCREMENT BY 1
                NOCACHE
                NOCYCLE';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_sequences
     WHERE sequence_name = 'WORLD_OBJECT_SEQ';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE SEQUENCE WORLD_OBJECT_SEQ
                START WITH 1
                INCREMENT BY 1
                NOCACHE
                NOCYCLE';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tables
     WHERE table_name = 'WORLD_OBJECT';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE WORLD_OBJECT (
                WORLD_OBJECT_ID NUMBER(19)         NOT NULL,
                OBJECT_CODE     VARCHAR2(40 CHAR)  NOT NULL,
                DISPLAY_NAME    VARCHAR2(100 CHAR) NOT NULL,
                CATEGORY        VARCHAR2(20 CHAR)  NOT NULL,
                ENABLED         CHAR(1) DEFAULT ''Y'' NOT NULL,
                CREATED_AT      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
                UPDATED_AT      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
                CONSTRAINT PK_WORLD_OBJECT PRIMARY KEY (WORLD_OBJECT_ID),
                CONSTRAINT UQ_WORLD_OBJECT_CODE UNIQUE (OBJECT_CODE),
                CONSTRAINT CK_WORLD_OBJECT_CATEGORY CHECK (CATEGORY IN (
                    ''MOVEMENT'', ''CREATIVE'', ''FOOD'', ''LEARNING'',
                    ''SOCIAL'', ''OUTDOOR'', ''ORGANIZING'', ''CULTURE''
                )),
                CONSTRAINT CK_WORLD_OBJECT_ENABLED CHECK (ENABLED IN (''Y'', ''N''))
            )';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tables
     WHERE table_name = 'WORLD_OBJECT_LEVEL';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE WORLD_OBJECT_LEVEL (
                WORLD_OBJECT_ID    NUMBER(19)         NOT NULL,
                OBJECT_LEVEL       NUMBER(3)          NOT NULL,
                REQUIRED_EXPERIENCE NUMBER(10) DEFAULT 0 NOT NULL,
                GLB_ASSET_URI      VARCHAR2(500 CHAR) NOT NULL,
                ASSET_LOCATION     VARCHAR2(10 CHAR)  NOT NULL,
                ANIMATION_NAME     VARCHAR2(100 CHAR),
                CREATED_AT         TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
                CONSTRAINT PK_WORLD_OBJECT_LEVEL PRIMARY KEY (WORLD_OBJECT_ID, OBJECT_LEVEL),
                CONSTRAINT FK_WORLD_OBJECT_LEVEL_OBJECT
                    FOREIGN KEY (WORLD_OBJECT_ID) REFERENCES WORLD_OBJECT (WORLD_OBJECT_ID)
                    ON DELETE CASCADE,
                CONSTRAINT CK_WORLD_OBJECT_LEVEL_NUMBER CHECK (OBJECT_LEVEL >= 1),
                CONSTRAINT CK_WORLD_OBJECT_LEVEL_EXP CHECK (REQUIRED_EXPERIENCE >= 0),
                CONSTRAINT CK_WORLD_OBJECT_LEVEL_LOCATION CHECK (
                    ASSET_LOCATION IN (''BUNDLE'', ''CDN'')
                )
            )';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tables
     WHERE table_name = 'USER_WORLD_OBJECT';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE USER_WORLD_OBJECT (
                USER_ID          NUMBER(19)   NOT NULL,
                WORLD_OBJECT_ID  NUMBER(19)   NOT NULL,
                CURRENT_LEVEL    NUMBER(3)    NOT NULL,
                EXPERIENCE      NUMBER(10) DEFAULT 0 NOT NULL,
                PLACEMENT_X      NUMBER(10,4) DEFAULT 0 NOT NULL,
                PLACEMENT_Y      NUMBER(10,4) DEFAULT 0 NOT NULL,
                PLACEMENT_Z      NUMBER(10,4) DEFAULT 0 NOT NULL,
                ROTATION_Y       NUMBER(10,4) DEFAULT 0 NOT NULL,
                SCALE_VALUE      NUMBER(10,4) DEFAULT 1 NOT NULL,
                CREATED_AT       TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
                UPDATED_AT       TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
                CONSTRAINT PK_USER_WORLD_OBJECT PRIMARY KEY (USER_ID, WORLD_OBJECT_ID),
                CONSTRAINT FK_USER_WORLD_OBJECT_LEVEL
                    FOREIGN KEY (WORLD_OBJECT_ID, CURRENT_LEVEL)
                    REFERENCES WORLD_OBJECT_LEVEL (WORLD_OBJECT_ID, OBJECT_LEVEL),
                CONSTRAINT CK_USER_WORLD_OBJECT_EXP CHECK (EXPERIENCE >= 0),
                CONSTRAINT CK_USER_WORLD_OBJECT_SCALE CHECK (SCALE_VALUE > 0)
            )';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
    table_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tab_columns
     WHERE table_name = 'USER_PERSONALITY_PROFILE'
       AND column_name = 'PHYSICAL_ACTIVITY_SCORE';

    SELECT COUNT(*)
      INTO table_count
      FROM user_tables
     WHERE table_name = 'USER_PERSONALITY_PROFILE';

    IF object_count = 0 AND table_count = 1 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE USER_PERSONALITY_PROFILE
            ADD PHYSICAL_ACTIVITY_SCORE NUMBER(1) DEFAULT 0 NOT NULL';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
    table_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_constraints
     WHERE constraint_name = 'CK_USER_PHYSICAL_ACTIVITY';

    SELECT COUNT(*)
      INTO table_count
      FROM user_tables
     WHERE table_name = 'USER_PERSONALITY_PROFILE';

    IF object_count = 0 AND table_count = 1 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE USER_PERSONALITY_PROFILE
            ADD CONSTRAINT CK_USER_PHYSICAL_ACTIVITY
            CHECK (PHYSICAL_ACTIVITY_SCORE IN (0, 1, 2))';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
    table_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tab_columns
     WHERE table_name = 'USER_PERSONALITY_PROFILE'
       AND column_name = 'COMPLETED_MISSION_COUNT';

    SELECT COUNT(*)
      INTO table_count
      FROM user_tables
     WHERE table_name = 'USER_PERSONALITY_PROFILE';

    IF object_count = 0 AND table_count = 1 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE USER_PERSONALITY_PROFILE
            ADD COMPLETED_MISSION_COUNT NUMBER(10) DEFAULT 0 NOT NULL';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
    table_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_constraints
     WHERE constraint_name = 'CK_USER_COMPLETED_MISSION_COUNT';

    SELECT COUNT(*)
      INTO table_count
      FROM user_tables
     WHERE table_name = 'USER_PERSONALITY_PROFILE';

    IF object_count = 0 AND table_count = 1 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE USER_PERSONALITY_PROFILE
            ADD CONSTRAINT CK_USER_COMPLETED_MISSION_COUNT
            CHECK (COMPLETED_MISSION_COUNT >= 0)';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_sequences
     WHERE sequence_name = 'MISSION_SEQ';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE SEQUENCE MISSION_SEQ
                START WITH 1
                INCREMENT BY 1
                NOCACHE
                NOCYCLE';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tables
     WHERE table_name = 'MISSION';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE MISSION (
                MISSION_ID          NUMBER(19)         NOT NULL,
                TITLE               VARCHAR2(100 CHAR) NOT NULL,
                TITLE_NORMALIZED    VARCHAR2(100 CHAR) NOT NULL,
                DESCRIPTION         VARCHAR2(500 CHAR) NOT NULL,
                CATEGORY            VARCHAR2(20 CHAR)  NOT NULL,
                DIFFICULTY          NUMBER(1)          NOT NULL,
                ESTIMATED_MINUTES   NUMBER(3)          NOT NULL,
                INDOOR_OUTDOOR      NUMBER(1)          NOT NULL,
                SOCIAL_LEVEL        NUMBER(1)          NOT NULL,
                ACTIVITY_LEVEL      NUMBER(1)          NOT NULL,
                NOVELTY_LEVEL       NUMBER(1)          NOT NULL,
                ACTION_TYPE         VARCHAR2(24 CHAR)  NOT NULL,
                CREATIVITY_LEVEL    NUMBER(1)          NOT NULL,
                UNPREDICTABILITY_LEVEL NUMBER(1)       NOT NULL,
                COMFORT_ZONE_DISTANCE NUMBER(1)        NOT NULL,
                COST_LEVEL          NUMBER(1)          NOT NULL,
                TAGS                VARCHAR2(400 CHAR) NOT NULL,
                ENABLED             CHAR(1) DEFAULT ''Y'' NOT NULL,
                SOURCE_TYPE         VARCHAR2(8 CHAR) DEFAULT ''BASE'' NOT NULL,
                CONTENT_FINGERPRINT VARCHAR2(64 CHAR) NOT NULL,
                CREATED_AT          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
                CONSTRAINT PK_MISSION PRIMARY KEY (MISSION_ID),
                CONSTRAINT UK_MISSION_TITLE_NORMALIZED UNIQUE (TITLE_NORMALIZED),
                CONSTRAINT UK_MISSION_FINGERPRINT UNIQUE (CONTENT_FINGERPRINT),
                CONSTRAINT CK_MISSION_CATEGORY CHECK (CATEGORY IN (
                    ''MOVEMENT'', ''CREATIVE'', ''FOOD'', ''LEARNING'',
                    ''SOCIAL'', ''OUTDOOR'', ''ORGANIZING'', ''CULTURE''
                )),
                CONSTRAINT CK_MISSION_DIFFICULTY CHECK (DIFFICULTY BETWEEN 1 AND 3),
                CONSTRAINT CK_MISSION_ESTIMATED_MINUTES CHECK (ESTIMATED_MINUTES BETWEEN 1 AND 180),
                CONSTRAINT CK_MISSION_INDOOR_OUTDOOR CHECK (INDOOR_OUTDOOR IN (-1, 0, 1)),
                CONSTRAINT CK_MISSION_SOCIAL_LEVEL CHECK (SOCIAL_LEVEL IN (-1, 0, 1)),
                CONSTRAINT CK_MISSION_ACTIVITY_LEVEL CHECK (ACTIVITY_LEVEL IN (0, 1, 2)),
                CONSTRAINT CK_MISSION_NOVELTY_LEVEL CHECK (NOVELTY_LEVEL IN (0, 1, 2)),
                CONSTRAINT CK_MISSION_ACTION_TYPE CHECK (ACTION_TYPE IN (
                    ''EXPLORE'', ''OBSERVE'', ''CREATE'', ''CONNECT'', ''ORGANIZE'',
                    ''EXERCISE'', ''ASK'', ''PRACTICE'', ''TASTE'', ''LISTEN''
                )),
                CONSTRAINT CK_MISSION_CREATIVITY CHECK (CREATIVITY_LEVEL IN (0, 1, 2)),
                CONSTRAINT CK_MISSION_UNPREDICTABILITY CHECK (UNPREDICTABILITY_LEVEL IN (0, 1, 2)),
                CONSTRAINT CK_MISSION_COMFORT_DISTANCE CHECK (COMFORT_ZONE_DISTANCE IN (0, 1, 2)),
                CONSTRAINT CK_MISSION_COST_LEVEL CHECK (COST_LEVEL IN (0, 1, 2)),
                CONSTRAINT CK_MISSION_TAGS CHECK (REGEXP_LIKE(TAGS, ''^[A-Z0-9_가-힣]+(,[A-Z0-9_가-힣]+)*$'')),
                CONSTRAINT CK_MISSION_TAG_COUNT CHECK (REGEXP_COUNT(TAGS, '','') <= 9),
                CONSTRAINT CK_MISSION_TAG_LENGTH CHECK (
                    NOT REGEXP_LIKE(TAGS, ''(^|,)[^,]{31}'')
                ),
                CONSTRAINT CK_MISSION_ENABLED CHECK (ENABLED IN (''Y'', ''N'')),
                CONSTRAINT CK_MISSION_SOURCE_TYPE CHECK (SOURCE_TYPE IN (''BASE'', ''LLM''))
            )';
    END IF;
END;
/

DECLARE
    column_count NUMBER;
    PROCEDURE add_mission_column_if_missing(
        column_name_value VARCHAR2,
        definition_value VARCHAR2
    ) IS
    BEGIN
        SELECT COUNT(*) INTO column_count
          FROM user_tab_columns
         WHERE table_name = 'MISSION' AND column_name = column_name_value;
        IF column_count = 0 THEN
            EXECUTE IMMEDIATE 'ALTER TABLE MISSION ADD (' || definition_value || ')';
        END IF;
    END;
BEGIN
    add_mission_column_if_missing('ACTION_TYPE',
        'ACTION_TYPE VARCHAR2(24 CHAR) DEFAULT ''EXPLORE'' NOT NULL');
    add_mission_column_if_missing('CREATIVITY_LEVEL',
        'CREATIVITY_LEVEL NUMBER(1) DEFAULT 0 NOT NULL');
    add_mission_column_if_missing('UNPREDICTABILITY_LEVEL',
        'UNPREDICTABILITY_LEVEL NUMBER(1) DEFAULT 0 NOT NULL');
    add_mission_column_if_missing('COMFORT_ZONE_DISTANCE',
        'COMFORT_ZONE_DISTANCE NUMBER(1) DEFAULT 1 NOT NULL');
    add_mission_column_if_missing('COST_LEVEL',
        'COST_LEVEL NUMBER(1) DEFAULT 0 NOT NULL');
    add_mission_column_if_missing('TAGS',
        'TAGS VARCHAR2(400 CHAR) DEFAULT ''GENERAL'' NOT NULL');
END;
/

DECLARE
    constraint_count NUMBER;
    PROCEDURE add_mission_constraint_if_missing(
        name_value VARCHAR2,
        definition_value VARCHAR2
    ) IS
    BEGIN
        SELECT COUNT(*) INTO constraint_count
          FROM user_constraints
         WHERE constraint_name = name_value;
        IF constraint_count = 0 THEN
            EXECUTE IMMEDIATE 'ALTER TABLE MISSION ADD CONSTRAINT '
                    || name_value || ' ' || definition_value;
        END IF;
    END;
BEGIN
    add_mission_constraint_if_missing('CK_MISSION_ACTION_TYPE',
        'CHECK (ACTION_TYPE IN (''EXPLORE'', ''OBSERVE'', ''CREATE'', ''CONNECT'', '
        || '''ORGANIZE'', ''EXERCISE'', ''ASK'', ''PRACTICE'', ''TASTE'', ''LISTEN''))');
    add_mission_constraint_if_missing('CK_MISSION_CREATIVITY',
        'CHECK (CREATIVITY_LEVEL IN (0, 1, 2))');
    add_mission_constraint_if_missing('CK_MISSION_UNPREDICTABILITY',
        'CHECK (UNPREDICTABILITY_LEVEL IN (0, 1, 2))');
    add_mission_constraint_if_missing('CK_MISSION_COMFORT_DISTANCE',
        'CHECK (COMFORT_ZONE_DISTANCE IN (0, 1, 2))');
    add_mission_constraint_if_missing('CK_MISSION_COST_LEVEL',
        'CHECK (COST_LEVEL IN (0, 1, 2))');
    add_mission_constraint_if_missing('CK_MISSION_TAG_COUNT',
        'CHECK (REGEXP_COUNT(TAGS, '','') <= 9)');
END;
/

DECLARE
    constraint_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO constraint_count
      FROM user_constraints
     WHERE constraint_name = 'CK_MISSION_TAGS';
    IF constraint_count > 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE MISSION DROP CONSTRAINT CK_MISSION_TAGS';
    END IF;

    SELECT COUNT(*) INTO constraint_count
      FROM user_constraints
     WHERE constraint_name = 'CK_MISSION_TAG_LENGTH';
    IF constraint_count > 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE MISSION DROP CONSTRAINT CK_MISSION_TAG_LENGTH';
    END IF;

    EXECUTE IMMEDIATE 'ALTER TABLE MISSION ADD CONSTRAINT CK_MISSION_TAGS '
        || 'CHECK (REGEXP_LIKE(TAGS, ''^[A-Z0-9_가-힣]+(,[A-Z0-9_가-힣]+)*$''))';
    EXECUTE IMMEDIATE 'ALTER TABLE MISSION ADD CONSTRAINT CK_MISSION_TAG_LENGTH '
        || 'CHECK (NOT REGEXP_LIKE(TAGS, ''(^|,)[^,]{31}''))';
END;
/

UPDATE MISSION SET ENABLED = 'N';

MERGE INTO MISSION target
USING (
    SELECT 'M001' seed_code, '평소 사용하지 않던 스트레칭 동작 세 가지 해보기' title, '평소 사용하지 않던 스트레칭 동작 세 가지 해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 1 difficulty, 15 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 2 activity_level,
           0 novelty_level, 'EXERCISE' action_type,
           0 creativity_level, 0 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M001,스트레칭,몸,변화' tags FROM dual
    UNION ALL
    SELECT 'M002' seed_code, '목적지를 정하지 않고 10분 동안 걸어보기' title, '목적지를 정하지 않고 10분 동안 걸어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 15 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           0 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M002,걷기,탐색,즉흥' tags FROM dual
    UNION ALL
    SELECT 'M003' seed_code, '좋아하는 노래 한 곡 동안 리듬에 맞춰 움직여보기' title, '좋아하는 노래 한 곡 동안 리듬에 맞춰 움직여보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 15 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 2 activity_level,
           1 novelty_level, 'PRACTICE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M003,음악,리듬,움직임' tags FROM dual
    UNION ALL
    SELECT 'M004' seed_code, '오늘 한 번은 엘리베이터 대신 계단 이용하기' title, '오늘 한 번은 엘리베이터 대신 계단 이용하기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 20 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 2 activity_level,
           0 novelty_level, 'EXERCISE' action_type,
           0 creativity_level, 0 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M004,계단,운동,생활' tags FROM dual
    UNION ALL
    SELECT 'M005' seed_code, '걸으면서 평소 눈에 들어오지 않던 간판 다섯 개 찾아보기' title, '걸으면서 평소 눈에 들어오지 않던 간판 다섯 개 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 15 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 2 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           0 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M005,걷기,관찰,거리' tags FROM dual
    UNION ALL
    SELECT 'M006' seed_code, '한 번도 해보지 않은 간단한 균형 동작 시도하기' title, '한 번도 해보지 않은 간단한 균형 동작 시도하기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 15 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 2 activity_level,
           1 novelty_level, 'PRACTICE' action_type,
           1 creativity_level, 1 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M006,균형,몸,도전' tags FROM dual
    UNION ALL
    SELECT 'M007' seed_code, '평소보다 한 정거장 먼저 내려 걸어보기' title, '평소보다 한 정거장 먼저 내려 걸어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 20 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           0 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M007,이동,걷기,새로운길' tags FROM dual
    UNION ALL
    SELECT 'M008' seed_code, '나만의 3분짜리 간단 운동 순서를 만들어 실행해보기' title, '나만의 3분짜리 간단 운동 순서를 만들어 실행해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 15 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 2 activity_level,
           1 novelty_level, 'CREATE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M008,운동,창작,루틴' tags FROM dual
    UNION ALL
    SELECT 'M009' seed_code, '가까운 목적지 하나를 정해 빠른 걸음으로 다녀오기' title, '가까운 목적지 하나를 정해 빠른 걸음으로 다녀오기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 20 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 2 activity_level,
           1 novelty_level, 'EXERCISE' action_type,
           0 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M009,걷기,속도,운동' tags FROM dual
    UNION ALL
    SELECT 'M010' seed_code, '몸을 움직여보고 평소 잘 쓰지 않는 부위 하나 찾아보기' title, '몸을 움직여보고 평소 잘 쓰지 않는 부위 하나 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 1 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M010,신체감각,관찰' tags FROM dual
    UNION ALL
    SELECT 'M011' seed_code, '익숙하지 않은 손으로 간단한 일 하나 해보기' title, '익숙하지 않은 손으로 간단한 일 하나 해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 15 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'PRACTICE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M011,반대손,감각,변화' tags FROM dual
    UNION ALL
    SELECT 'M012' seed_code, '지도에서 가까운 곳 하나를 무작위로 골라 걸어가보기' title, '지도에서 가까운 곳 하나를 무작위로 골라 걸어가보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 3 difficulty, 15 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           0 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M012,지도,탐색,즉흥' tags FROM dual
    UNION ALL
    SELECT 'M013' seed_code, '평소 하지 않던 움직임 다섯 개를 연결해 짧은 동작 만들어보기' title, '평소 하지 않던 움직임 다섯 개를 연결해 짧은 동작 만들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 15 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 2 activity_level,
           1 novelty_level, 'CREATE' action_type,
           2 creativity_level, 1 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M013,움직임,창작,신체' tags FROM dual
    UNION ALL
    SELECT 'M014' seed_code, '좋아하지 않던 색 두 가지를 사용해 작은 그림 그리기' title, '좋아하지 않던 색 두 가지를 사용해 작은 그림 그리기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'CREATE' action_type,
           2 creativity_level, 1 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M014,색,그림,창작' tags FROM dual
    UNION ALL
    SELECT 'M015' seed_code, '주변 물건 세 개만 사용해 재미있는 사진 구성하기' title, '주변 물건 세 개만 사용해 재미있는 사진 구성하기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 10 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M015,사진,구도,물건' tags FROM dual
    UNION ALL
    SELECT 'M016' seed_code, '아무 단어 세 개를 골라 네 문장짜리 이야기 만들기' title, '아무 단어 세 개를 골라 네 문장짜리 이야기 만들기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M016,글쓰기,이야기,단어' tags FROM dual
    UNION ALL
    SELECT 'M017' seed_code, '주변에서 마음에 드는 색 조합 세 가지 찾아 기록하기' title, '주변에서 마음에 드는 색 조합 세 가지 찾아 기록하기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 1 difficulty, 10 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 1 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M017,색,관찰,디자인' tags FROM dual
    UNION ALL
    SELECT 'M018' seed_code, '버릴 종이나 포장재로 작은 물건 하나 만들어보기' title, '버릴 종이나 포장재로 작은 물건 하나 만들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M018,업사이클,만들기' tags FROM dual
    UNION ALL
    SELECT 'M019' seed_code, '오늘 들은 소리 세 가지를 녹음해 짧은 소리 모음 만들기' title, '오늘 들은 소리 세 가지를 녹음해 짧은 소리 모음 만들기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 10 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M019,소리,녹음,창작' tags FROM dual
    UNION ALL
    SELECT 'M020' seed_code, '평소 사용하지 않던 그림 도구나 앱 기능 하나 사용해보기' title, '평소 사용하지 않던 그림 도구나 앱 기능 하나 사용해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'PRACTICE' action_type,
           2 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M020,도구,디지털,그림' tags FROM dual
    UNION ALL
    SELECT 'M021' seed_code, '오늘 하루를 이모지 다섯 개만으로 표현해보기' title, '오늘 하루를 이모지 다섯 개만으로 표현해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M021,표현,이모지,기록' tags FROM dual
    UNION ALL
    SELECT 'M022' seed_code, '평소 관심 없던 디자인 스타일 하나 찾아 특징 세 개 적기' title, '평소 관심 없던 디자인 스타일 하나 찾아 특징 세 개 적기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 10 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M022,디자인,탐색,스타일' tags FROM dual
    UNION ALL
    SELECT 'M023' seed_code, '눈을 감고 30초 동안 선을 그린 뒤 그림으로 발전시키기' title, '눈을 감고 30초 동안 선을 그린 뒤 그림으로 발전시키기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 3 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M023,즉흥,그림,우연' tags FROM dual
    UNION ALL
    SELECT 'M024' seed_code, '익숙한 물건 하나의 새로운 사용법 세 가지 생각해보기' title, '익숙한 물건 하나의 새로운 사용법 세 가지 생각해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 10 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M024,아이디어,사물,발상' tags FROM dual
    UNION ALL
    SELECT 'M025' seed_code, '좋아하는 콘텐츠 제목을 전혀 다른 장르처럼 바꿔보기' title, '좋아하는 콘텐츠 제목을 전혀 다른 장르처럼 바꿔보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M025,제목,콘텐츠,발상' tags FROM dual
    UNION ALL
    SELECT 'M026' seed_code, '지인에게 임의의 단어 하나를 받아 그 단어로 무언가 만들어보기' title, '지인에게 임의의 단어 하나를 받아 그 단어로 무언가 만들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           2 novelty_level, 'ASK' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M026,협업,단어,창작' tags FROM dual
    UNION ALL
    SELECT 'M027' seed_code, '평소 고르지 않던 맛의 음료 하나 골라보기' title, '평소 고르지 않던 맛의 음료 하나 골라보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 1 cost_level,
           'M027,맛,음료,선택' tags FROM dual
    UNION ALL
    SELECT 'M028' seed_code, '집에 있는 재료 두 가지를 평소와 다르게 조합해보기' title, '집에 있는 재료 두 가지를 평소와 다르게 조합해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 2 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M028,조합,요리,재료' tags FROM dual
    UNION ALL
    SELECT 'M029' seed_code, '먹고 있는 음식에서 느껴지는 맛을 세 단어로 표현해보기' title, '먹고 있는 음식에서 느껴지는 맛을 세 단어로 표현해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 1 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 1 cost_level,
           'M029,맛,감각,관찰' tags FROM dual
    UNION ALL
    SELECT 'M030' seed_code, '편의점이나 마트에서 처음 보는 간식 하나 찾아보기' title, '편의점이나 마트에서 처음 보는 간식 하나 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 1 cost_level,
           'M030,간식,탐색,마트' tags FROM dual
    UNION ALL
    SELECT 'M031' seed_code, '카페나 식당에서 직원에게 추천 메뉴 하나 물어보기' title, '카페나 식당에서 직원에게 추천 메뉴 하나 물어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 3 difficulty, 5 estimated_minutes,
           1 indoor_outdoor, 1 social_level, 0 activity_level,
           2 novelty_level, 'ASK' action_type,
           0 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 1 cost_level,
           'M031,질문,메뉴,사회' tags FROM dual
    UNION ALL
    SELECT 'M032' seed_code, '익숙한 음식 하나에 새로운 토핑 한 가지 추가해보기' title, '익숙한 음식 하나에 새로운 토핑 한 가지 추가해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 2 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M032,토핑,요리,변화' tags FROM dual
    UNION ALL
    SELECT 'M033' seed_code, '평소 먹지 않던 과일이나 채소 하나 골라보기' title, '평소 먹지 않던 과일이나 채소 하나 골라보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 1 unpredictability_level,
           2 comfort_zone_distance, 1 cost_level,
           'M033,식재료,탐색' tags FROM dual
    UNION ALL
    SELECT 'M034' seed_code, '음식 하나를 천천히 먹으며 식감 차이를 찾아보기' title, '음식 하나를 천천히 먹으며 식감 차이를 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 1 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M034,식감,감각' tags FROM dual
    UNION ALL
    SELECT 'M035' seed_code, '가지고 있는 재료로 새로운 음료 조합 하나 만들어보기' title, '가지고 있는 재료로 새로운 음료 조합 하나 만들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 2 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           1 novelty_level, 'CREATE' action_type,
           2 creativity_level, 1 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M035,음료,조합,창작' tags FROM dual
    UNION ALL
    SELECT 'M036' seed_code, '평소 지나치던 작은 식품점이나 베이커리 구경하기' title, '평소 지나치던 작은 식품점이나 베이커리 구경하기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 1 cost_level,
           'M036,가게,음식,탐색' tags FROM dual
    UNION ALL
    SELECT 'M037' seed_code, '평소와 다른 방식으로 과일이나 간식을 플레이팅해보기' title, '평소와 다른 방식으로 과일이나 간식을 플레이팅해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 2 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           1 novelty_level, 'PRACTICE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M037,플레이팅,디자인' tags FROM dual
    UNION ALL
    SELECT 'M038' seed_code, '주변 사람에게 좋아하는 간식 하나 추천받아 기록하기' title, '주변 사람에게 좋아하는 간식 하나 추천받아 기록하기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           1 novelty_level, 'ASK' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 1 cost_level,
           'M038,추천,음식,대화' tags FROM dual
    UNION ALL
    SELECT 'M039' seed_code, '메뉴판에서 평소라면 선택하지 않을 메뉴 하나 살펴보기' title, '메뉴판에서 평소라면 선택하지 않을 메뉴 하나 살펴보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 3 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 1 cost_level,
           'M039,메뉴,선택,새로움' tags FROM dual
    UNION ALL
    SELECT 'M040' seed_code, '평소 관심 없던 분야의 글 하나 읽어보기' title, '평소 관심 없던 분야의 글 하나 읽어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M040,읽기,탐색,지식' tags FROM dual
    UNION ALL
    SELECT 'M041' seed_code, '새로운 외국어 표현 하나 익혀 소리 내어 말해보기' title, '새로운 외국어 표현 하나 익혀 소리 내어 말해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'PRACTICE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M041,언어,학습,발음' tags FROM dual
    UNION ALL
    SELECT 'M042' seed_code, '서점에서 평소 가지 않던 코너의 책 한 권 펼쳐보기' title, '서점에서 평소 가지 않던 코너의 책 한 권 펼쳐보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M042,책,서점,탐색' tags FROM dual
    UNION ALL
    SELECT 'M043' seed_code, '오늘 처음 알게 된 사실 하나를 한 문장으로 기록하기' title, '오늘 처음 알게 된 사실 하나를 한 문장으로 기록하기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 1 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M043,기록,지식' tags FROM dual
    UNION ALL
    SELECT 'M044' seed_code, '사용 중인 앱에서 한 번도 써보지 않은 기능 하나 사용해보기' title, '사용 중인 앱에서 한 번도 써보지 않은 기능 하나 사용해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'PRACTICE' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M044,앱,기능,학습' tags FROM dual
    UNION ALL
    SELECT 'M045' seed_code, '평소 검색하지 않던 주제의 짧은 강의 하나 찾아보기' title, '평소 검색하지 않던 주제의 짧은 강의 하나 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M045,강의,탐색' tags FROM dual
    UNION ALL
    SELECT 'M046' seed_code, '오늘 배운 내용을 그림이나 도식 하나로 표현해보기' title, '오늘 배운 내용을 그림이나 도식 하나로 표현해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'CREATE' action_type,
           2 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M046,시각화,학습' tags FROM dual
    UNION ALL
    SELECT 'M047' seed_code, '다른 사람에게 요즘 새로 알게 된 것 하나 물어보기' title, '다른 사람에게 요즘 새로 알게 된 것 하나 물어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           1 novelty_level, 'ASK' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M047,질문,지식,대화' tags FROM dual
    UNION ALL
    SELECT 'M048' seed_code, '알고만 있던 기능이나 기술 하나를 실제로 10분 사용해보기' title, '알고만 있던 기능이나 기술 하나를 실제로 10분 사용해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'PRACTICE' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M048,실습,기술' tags FROM dual
    UNION ALL
    SELECT 'M049' seed_code, '위키나 사전에서 임의의 항목 하나를 골라 읽어보기' title, '위키나 사전에서 임의의 항목 하나를 골라 읽어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 3 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M049,랜덤,지식,탐색' tags FROM dual
    UNION ALL
    SELECT 'M050' seed_code, '거리에서 의미를 모르는 표지나 기호 하나 찾아 알아보기' title, '거리에서 의미를 모르는 표지나 기호 하나 찾아 알아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M050,표지,관찰,학습' tags FROM dual
    UNION ALL
    SELECT 'M051' seed_code, '익숙한 개념 하나를 초등학생에게 설명하듯 세 문장으로 적기' title, '익숙한 개념 하나를 초등학생에게 설명하듯 세 문장으로 적기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'CREATE' action_type,
           2 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M051,설명,정리,학습' tags FROM dual
    UNION ALL
    SELECT 'M052' seed_code, '평소 쓰지 않던 키보드 단축키 하나 익혀 실제로 사용해보기' title, '평소 쓰지 않던 키보드 단축키 하나 익혀 실제로 사용해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'PRACTICE' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M052,도구,단축키,실습' tags FROM dual
    UNION ALL
    SELECT 'M053' seed_code, '한동안 연락하지 않았던 사람에게 짧은 안부 보내기' title, '한동안 연락하지 않았던 사람에게 짧은 안부 보내기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 1 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           1 novelty_level, 'CONNECT' action_type,
           0 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M053,연락,관계' tags FROM dual
    UNION ALL
    SELECT 'M054' seed_code, '친한 사람에게 최근 재미있었던 일을 하나 물어보기' title, '친한 사람에게 최근 재미있었던 일을 하나 물어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 1 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           1 novelty_level, 'ASK' action_type,
           0 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M054,질문,대화' tags FROM dual
    UNION ALL
    SELECT 'M055' seed_code, '평소 표현하지 않던 감사 한마디 전하기' title, '평소 표현하지 않던 감사 한마디 전하기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           1 novelty_level, 'CONNECT' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M055,감사,관계' tags FROM dual
    UNION ALL
    SELECT 'M056' seed_code, '가게 직원에게 상품이나 메뉴 하나 추천받기' title, '가게 직원에게 상품이나 메뉴 하나 추천받기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 3 difficulty, 5 estimated_minutes,
           1 indoor_outdoor, 1 social_level, 0 activity_level,
           2 novelty_level, 'ASK' action_type,
           0 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M056,질문,직원,추천' tags FROM dual
    UNION ALL
    SELECT 'M057' seed_code, '지인에게 사진 한 장을 보내고 관련된 이야기를 나눠보기' title, '지인에게 사진 한 장을 보내고 관련된 이야기를 나눠보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           2 novelty_level, 'CONNECT' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M057,사진,대화' tags FROM dual
    UNION ALL
    SELECT 'M058' seed_code, '주변 사람에게 요즘 자주 듣는 음악 하나 물어보기' title, '주변 사람에게 요즘 자주 듣는 음악 하나 물어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           2 novelty_level, 'ASK' action_type,
           0 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M058,음악,추천,질문' tags FROM dual
    UNION ALL
    SELECT 'M059' seed_code, '평소 먼저 인사하지 않던 사람에게 먼저 인사해보기' title, '평소 먼저 인사하지 않던 사람에게 먼저 인사해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 3 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           2 novelty_level, 'CONNECT' action_type,
           0 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M059,인사,사회' tags FROM dual
    UNION ALL
    SELECT 'M060' seed_code, '친구에게 최근 새로 시작한 것이 있는지 물어보기' title, '친구에게 최근 새로 시작한 것이 있는지 물어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           2 novelty_level, 'ASK' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M060,질문,새로움' tags FROM dual
    UNION ALL
    SELECT 'M061' seed_code, '상대의 좋은 점 하나를 구체적으로 말해보기' title, '상대의 좋은 점 하나를 구체적으로 말해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           1 novelty_level, 'CONNECT' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M061,칭찬,관계' tags FROM dual
    UNION ALL
    SELECT 'M062' seed_code, '필요할 때 검색 대신 주변 사람에게 간단한 정보를 물어보기' title, '필요할 때 검색 대신 주변 사람에게 간단한 정보를 물어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 3 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, 1 social_level, 1 activity_level,
           2 novelty_level, 'ASK' action_type,
           0 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M062,질문,상호작용' tags FROM dual
    UNION ALL
    SELECT 'M063' seed_code, '평소 하지 않던 주제로 5분 정도 대화해보기' title, '평소 하지 않던 주제로 5분 정도 대화해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           2 novelty_level, 'CONNECT' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M063,대화,주제' tags FROM dual
    UNION ALL
    SELECT 'M064' seed_code, '지인에게 나와 다른 취향의 콘텐츠 하나 추천받기' title, '지인에게 나와 다른 취향의 콘텐츠 하나 추천받기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           2 novelty_level, 'ASK' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M064,추천,취향,대화' tags FROM dual
    UNION ALL
    SELECT 'M065' seed_code, '동네에서 한 번도 들어가 보지 않은 길 하나 걸어보기' title, '동네에서 한 번도 들어가 보지 않은 길 하나 걸어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 15 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           0 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M065,골목,탐색,걷기' tags FROM dual
    UNION ALL
    SELECT 'M066' seed_code, '주변에서 서로 다른 모양의 나뭇잎 세 개 찾아보기' title, '주변에서 서로 다른 모양의 나뭇잎 세 개 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M066,자연,관찰' tags FROM dual
    UNION ALL
    SELECT 'M067' seed_code, '평소 지나치던 건물 하나를 자세히 보고 특징 세 개 찾기' title, '평소 지나치던 건물 하나를 자세히 보고 특징 세 개 찾기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M067,건축,관찰' tags FROM dual
    UNION ALL
    SELECT 'M068' seed_code, '지도에서 가까운 공원이나 공간 하나를 골라 방문해보기' title, '지도에서 가까운 공원이나 공간 하나를 골라 방문해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 3 difficulty, 15 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           0 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M068,지도,공간,탐색' tags FROM dual
    UNION ALL
    SELECT 'M069' seed_code, '평소 사진 찍지 않던 피사체 하나를 골라 사진 찍기' title, '평소 사진 찍지 않던 피사체 하나를 골라 사진 찍기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M069,사진,거리,창작' tags FROM dual
    UNION ALL
    SELECT 'M070' seed_code, '5분 동안 주변에서 들리는 소리만 집중해서 들어보기' title, '5분 동안 주변에서 들리는 소리만 집중해서 들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M070,소리,관찰,감각' tags FROM dual
    UNION ALL
    SELECT 'M071' seed_code, '평소 이용하지 않는 출입구나 길을 이용해 목적지 가보기' title, '평소 이용하지 않는 출입구나 길을 이용해 목적지 가보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 15 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           0 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M071,이동,새로운길' tags FROM dual
    UNION ALL
    SELECT 'M072' seed_code, '거리에서 가장 눈에 띄는 색 세 가지 찾아보기' title, '거리에서 가장 눈에 띄는 색 세 가지 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M072,색,거리,관찰' tags FROM dual
    UNION ALL
    SELECT 'M073' seed_code, '목적지까지 일부러 한 번 다른 길로 돌아가보기' title, '목적지까지 일부러 한 번 다른 길로 돌아가보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 3 difficulty, 15 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           0 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M073,우회,탐색,걷기' tags FROM dual
    UNION ALL
    SELECT 'M074' seed_code, '오늘 본 풍경을 한 문장 제목으로 만들어보기' title, '오늘 본 풍경을 한 문장 제목으로 만들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M074,풍경,글쓰기' tags FROM dual
    UNION ALL
    SELECT 'M075' seed_code, '주변에서 계절이 느껴지는 요소 세 가지 찾아보기' title, '주변에서 계절이 느껴지는 요소 세 가지 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M075,계절,자연,관찰' tags FROM dual
    UNION ALL
    SELECT 'M076' seed_code, '평소 앉지 않던 장소에서 5분간 주변을 구경해보기' title, '평소 앉지 않던 장소에서 5분간 주변을 구경해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 15 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M076,공간,휴식,탐색' tags FROM dual
    UNION ALL
    SELECT 'M077' seed_code, '책상 위 물건 다섯 개의 위치를 바꿔보기' title, '책상 위 물건 다섯 개의 위치를 바꿔보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 1 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           0 novelty_level, 'ORGANIZE' action_type,
           1 creativity_level, 0 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M077,책상,정리,변화' tags FROM dual
    UNION ALL
    SELECT 'M078' seed_code, '서랍 하나를 평소와 다른 기준으로 정리해보기' title, '서랍 하나를 평소와 다른 기준으로 정리해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 2 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           1 novelty_level, 'ORGANIZE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M078,서랍,분류,정리' tags FROM dual
    UNION ALL
    SELECT 'M079' seed_code, '휴대폰 홈 화면에서 앱 세 개 위치 바꾸기' title, '휴대폰 홈 화면에서 앱 세 개 위치 바꾸기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 1 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           0 novelty_level, 'ORGANIZE' action_type,
           1 creativity_level, 0 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M079,스마트폰,정리' tags FROM dual
    UNION ALL
    SELECT 'M080' seed_code, '파일이나 사진 다섯 개를 새로운 기준으로 분류해보기' title, '파일이나 사진 다섯 개를 새로운 기준으로 분류해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'ORGANIZE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M080,파일,디지털,분류' tags FROM dual
    UNION ALL
    SELECT 'M081' seed_code, '방에서 한 달 이상 사용하지 않은 물건 세 개 찾아보기' title, '방에서 한 달 이상 사용하지 않은 물건 세 개 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 1 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M081,물건,관찰,정리' tags FROM dual
    UNION ALL
    SELECT 'M082' seed_code, '자주 사용하는 물건 하나의 보관 위치를 더 편한 곳으로 바꾸기' title, '자주 사용하는 물건 하나의 보관 위치를 더 편한 곳으로 바꾸기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 2 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           1 novelty_level, 'ORGANIZE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M082,공간,개선' tags FROM dual
    UNION ALL
    SELECT 'M083' seed_code, '해야 할 일 목록을 평소와 다른 방식으로 표현해보기' title, '해야 할 일 목록을 평소와 다른 방식으로 표현해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'CREATE' action_type,
           2 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M083,할일,시각화,정리' tags FROM dual
    UNION ALL
    SELECT 'M084' seed_code, '가방 안 물건을 모두 꺼내 필요한 것만 다시 넣기' title, '가방 안 물건을 모두 꺼내 필요한 것만 다시 넣기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 1 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           1 novelty_level, 'ORGANIZE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M084,가방,정리' tags FROM dual
    UNION ALL
    SELECT 'M085' seed_code, '책이나 물건을 색상 기준으로 잠시 재배치해보기' title, '책이나 물건을 색상 기준으로 잠시 재배치해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 2 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'ORGANIZE' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M085,색,배치,정리' tags FROM dual
    UNION ALL
    SELECT 'M086' seed_code, '생활 공간에서 불편하지만 익숙해진 부분 하나 찾아보기' title, '생활 공간에서 불편하지만 익숙해진 부분 하나 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 1 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M086,공간,관찰,개선' tags FROM dual
    UNION ALL
    SELECT 'M087' seed_code, '브라우저 북마크나 탭 다섯 개 정리하기' title, '브라우저 북마크나 탭 다섯 개 정리하기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 1 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'ORGANIZE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M087,디지털,브라우저' tags FROM dual
    UNION ALL
    SELECT 'M088' seed_code, '작은 공간 하나를 새로운 용도로 사용할 방법 생각해보기' title, '작은 공간 하나를 새로운 용도로 사용할 방법 생각해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 2 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M088,공간,아이디어,정리' tags FROM dual
    UNION ALL
    SELECT 'M089' seed_code, '평소 듣지 않던 장르의 음악 한 곡 끝까지 들어보기' title, '평소 듣지 않던 장르의 음악 한 곡 끝까지 들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'LISTEN' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M089,음악,장르,탐색' tags FROM dual
    UNION ALL
    SELECT 'M090' seed_code, '평소 보지 않던 장르의 영화 예고편 하나 보기' title, '평소 보지 않던 장르의 영화 예고편 하나 보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M090,영화,장르,탐색' tags FROM dual
    UNION ALL
    SELECT 'M091' seed_code, '광고나 포스터 하나를 보고 가장 눈에 띄는 요소 찾아보기' title, '광고나 포스터 하나를 보고 가장 눈에 띄는 요소 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 1 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M091,광고,디자인,관찰' tags FROM dual
    UNION ALL
    SELECT 'M092' seed_code, '다른 나라의 음악 한 곡 찾아 들어보기' title, '다른 나라의 음악 한 곡 찾아 들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 3 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M092,해외,음악,문화' tags FROM dual
    UNION ALL
    SELECT 'M093' seed_code, '평소 관심 없던 시대의 작품 하나 찾아보기' title, '평소 관심 없던 시대의 작품 하나 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M093,역사,예술,탐색' tags FROM dual
    UNION ALL
    SELECT 'M094' seed_code, '처음 듣는 팟캐스트나 라디오를 10분 들어보기' title, '처음 듣는 팟캐스트나 라디오를 10분 들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'LISTEN' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M094,오디오,콘텐츠' tags FROM dual
    UNION ALL
    SELECT 'M095' seed_code, '좋아하는 영화나 게임의 제목을 다른 장르처럼 바꿔보기' title, '좋아하는 영화나 게임의 제목을 다른 장르처럼 바꿔보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M095,영화,게임,창작' tags FROM dual
    UNION ALL
    SELECT 'M096' seed_code, '다른 나라의 일상 문화 한 가지 찾아보기' title, '다른 나라의 일상 문화 한 가지 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M096,해외,생활,문화' tags FROM dual
    UNION ALL
    SELECT 'M097' seed_code, '익숙한 노래를 들으며 처음 발견한 소리 하나 찾아보기' title, '익숙한 노래를 들으며 처음 발견한 소리 하나 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 1 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M097,음악,관찰' tags FROM dual
    UNION ALL
    SELECT 'M098' seed_code, '평소 읽지 않던 형태의 콘텐츠 하나 접해보기' title, '평소 읽지 않던 형태의 콘텐츠 하나 접해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 3 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M098,콘텐츠,탐색' tags FROM dual
    UNION ALL
    SELECT 'M099' seed_code, '오늘 본 콘텐츠 하나에 새로운 제목 붙여보기' title, '오늘 본 콘텐츠 하나에 새로운 제목 붙여보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M099,제목,콘텐츠,창작' tags FROM dual
    UNION ALL
    SELECT 'M100' seed_code, '지인에게 내가 잘 모르는 영화·음악·게임 하나 추천받기' title, '지인에게 내가 잘 모르는 영화·음악·게임 하나 추천받기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           2 novelty_level, 'ASK' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M100,추천,문화,대화' tags FROM dual
    UNION ALL
    SELECT 'M101' seed_code, '평소보다 천천히 움직이며 일상 동작 하나 수행해보기' title, '평소보다 천천히 움직이며 일상 동작 하나 수행해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 15 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 2 activity_level,
           1 novelty_level, 'PRACTICE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M101,속도,신체감각,변화' tags FROM dual
    UNION ALL
    SELECT 'M102' seed_code, '의자를 활용해 5분 동안 간단한 전신 운동 해보기' title, '의자를 활용해 5분 동안 간단한 전신 운동 해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 20 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 2 activity_level,
           1 novelty_level, 'EXERCISE' action_type,
           0 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M102,의자,전신,운동' tags FROM dual
    UNION ALL
    SELECT 'M103' seed_code, '평소보다 보폭을 조금 다르게 해서 짧게 걸어보기' title, '평소보다 보폭을 조금 다르게 해서 짧게 걸어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 15 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'PRACTICE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M103,보폭,걷기,감각' tags FROM dual
    UNION ALL
    SELECT 'M104' seed_code, '하루 중 내 자세가 가장 자주 흐트러지는 순간 찾아보기' title, '하루 중 내 자세가 가장 자주 흐트러지는 순간 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 1 difficulty, 10 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 1 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M104,자세,관찰,신체' tags FROM dual
    UNION ALL
    SELECT 'M105' seed_code, '벽을 이용한 간단한 운동 세 가지 시도해보기' title, '벽을 이용한 간단한 운동 세 가지 시도해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 15 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 2 activity_level,
           1 novelty_level, 'EXERCISE' action_type,
           0 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M105,벽,운동,신체' tags FROM dual
    UNION ALL
    SELECT 'M106' seed_code, '손가락을 평소와 다른 순서로 움직이는 동작 만들어 따라하기' title, '손가락을 평소와 다른 순서로 움직이는 동작 만들어 따라하기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 15 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'PRACTICE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M106,손,협응,도전' tags FROM dual
    UNION ALL
    SELECT 'M107' seed_code, '평소 이동하지 않는 시간대에 짧게 동네를 걸어보기' title, '평소 이동하지 않는 시간대에 짧게 동네를 걸어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 15 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           0 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M107,시간대,걷기,변화' tags FROM dual
    UNION ALL
    SELECT 'M108' seed_code, '5분 동안 앉지 않고 할 수 있는 일을 찾아 수행해보기' title, '5분 동안 앉지 않고 할 수 있는 일을 찾아 수행해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 15 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 2 activity_level,
           1 novelty_level, 'EXERCISE' action_type,
           0 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M108,생활,움직임,활동' tags FROM dual
    UNION ALL
    SELECT 'M109' seed_code, '거울을 보며 평소 해보지 않던 간단한 동작 따라 해보기' title, '거울을 보며 평소 해보지 않던 간단한 동작 따라 해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 15 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'PRACTICE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M109,거울,동작,신체' tags FROM dual
    UNION ALL
    SELECT 'M110' seed_code, '걸을 때 발바닥에 느껴지는 바닥의 차이를 세 가지 찾아보기' title, '걸을 때 발바닥에 느껴지는 바닥의 차이를 세 가지 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 15 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 2 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           0 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M110,촉감,걷기,감각' tags FROM dual
    UNION ALL
    SELECT 'M111' seed_code, '1분씩 다른 강도로 움직이며 몸의 변화 비교해보기' title, '1분씩 다른 강도로 움직이며 몸의 변화 비교해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 20 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'EXERCISE' action_type,
           0 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M111,강도,운동,비교' tags FROM dual
    UNION ALL
    SELECT 'M112' seed_code, '일상 동작 하나를 반대 방향이나 순서로 수행해보기' title, '일상 동작 하나를 반대 방향이나 순서로 수행해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 10 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'PRACTICE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M112,순서,동작,변화' tags FROM dual
    UNION ALL
    SELECT 'M113' seed_code, '세 가지 스트레칭을 조합해 나만의 시작 동작 만들어보기' title, '세 가지 스트레칭을 조합해 나만의 시작 동작 만들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'MOVEMENT' category, 2 difficulty, 15 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M113,스트레칭,조합,루틴' tags FROM dual
    UNION ALL
    SELECT 'M114' seed_code, '원 하나만 반복해서 사용해 작은 패턴 만들어보기' title, '원 하나만 반복해서 사용해 작은 패턴 만들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M114,패턴,도형,디자인' tags FROM dual
    UNION ALL
    SELECT 'M115' seed_code, '오늘 있었던 일을 영화 제목처럼 한 문장으로 만들어보기' title, '오늘 있었던 일을 영화 제목처럼 한 문장으로 만들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M115,제목,일상,글쓰기' tags FROM dual
    UNION ALL
    SELECT 'M116' seed_code, '무작위 숫자 세 개를 이용해 짧은 설정 하나 만들어보기' title, '무작위 숫자 세 개를 이용해 짧은 설정 하나 만들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 3 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M116,숫자,즉흥,이야기' tags FROM dual
    UNION ALL
    SELECT 'M117' seed_code, '주변 물건에서 얼굴처럼 보이는 형태 하나 찾아보기' title, '주변 물건에서 얼굴처럼 보이는 형태 하나 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M117,형태,관찰,상상' tags FROM dual
    UNION ALL
    SELECT 'M118' seed_code, '같은 문장을 세 가지 다른 분위기로 다시 써보기' title, '같은 문장을 세 가지 다른 분위기로 다시 써보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M118,글쓰기,분위기,표현' tags FROM dual
    UNION ALL
    SELECT 'M119' seed_code, '그림자를 이용해 재미있는 형태의 사진 한 장 만들어보기' title, '그림자를 이용해 재미있는 형태의 사진 한 장 만들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 10 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M119,그림자,사진,빛' tags FROM dual
    UNION ALL
    SELECT 'M120' seed_code, '익숙한 브랜드나 서비스의 이름을 새롭게 하나 지어보기' title, '익숙한 브랜드나 서비스의 이름을 새롭게 하나 지어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M120,네이밍,아이디어' tags FROM dual
    UNION ALL
    SELECT 'M121' seed_code, '한 가지 사물을 1분 안에 최대한 단순하게 그려보기' title, '한 가지 사물을 1분 안에 최대한 단순하게 그려보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'PRACTICE' action_type,
           2 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M121,스케치,단순화' tags FROM dual
    UNION ALL
    SELECT 'M122' seed_code, '서로 관련 없어 보이는 두 단어를 연결해 아이디어 하나 만들기' title, '서로 관련 없어 보이는 두 단어를 연결해 아이디어 하나 만들기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 3 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M122,연결,발상,단어' tags FROM dual
    UNION ALL
    SELECT 'M123' seed_code, '주변의 반복되는 모양을 찾아 나만의 무늬로 바꿔보기' title, '주변의 반복되는 모양을 찾아 나만의 무늬로 바꿔보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 10 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M123,패턴,관찰,창작' tags FROM dual
    UNION ALL
    SELECT 'M124' seed_code, '평범한 물건 하나에 가상의 특별한 기능을 만들어 설명해보기' title, '평범한 물건 하나에 가상의 특별한 기능을 만들어 설명해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M124,상상,제품,기능' tags FROM dual
    UNION ALL
    SELECT 'M125' seed_code, '오늘의 기분을 색이 아닌 모양 세 개로 표현해보기' title, '오늘의 기분을 색이 아닌 모양 세 개로 표현해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M125,감정,도형,표현' tags FROM dual
    UNION ALL
    SELECT 'M126' seed_code, '평소 접하지 않던 창작 방식 하나 찾아 5분간 따라 해보기' title, '평소 접하지 않던 창작 방식 하나 찾아 5분간 따라 해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CREATIVE' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M126,창작법,탐색,실험' tags FROM dual
    UNION ALL
    SELECT 'M127' seed_code, '음식의 향을 먼저 맡고 어떤 맛일지 예상해보기' title, '음식의 향을 먼저 맡고 어떤 맛일지 예상해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 1 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 1 cost_level,
           'M127,향,맛,예측' tags FROM dual
    UNION ALL
    SELECT 'M128' seed_code, '마트에서 평소 눈여겨보지 않던 식품 코너 하나 둘러보기' title, '마트에서 평소 눈여겨보지 않던 식품 코너 하나 둘러보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 1 cost_level,
           'M128,마트,식품,탐색' tags FROM dual
    UNION ALL
    SELECT 'M129' seed_code, '평소 먹던 간식을 다른 형태로 잘라 배치해보기' title, '평소 먹던 간식을 다른 형태로 잘라 배치해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 2 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M129,형태,간식,플레이팅' tags FROM dual
    UNION ALL
    SELECT 'M130' seed_code, '오늘 먹은 음식 중 가장 강하게 느껴진 향 하나 기록하기' title, '오늘 먹은 음식 중 가장 강하게 느껴진 향 하나 기록하기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 1 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 1 cost_level,
           'M130,향,기록,감각' tags FROM dual
    UNION ALL
    SELECT 'M131' seed_code, '평소 마시지 않던 종류의 차나 무카페인 음료 알아보기' title, '평소 마시지 않던 종류의 차나 무카페인 음료 알아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 1 cost_level,
           'M131,차,음료,탐색' tags FROM dual
    UNION ALL
    SELECT 'M132' seed_code, '한 가지 재료를 달거나 짜거나 새콤하게 변형할 방법 생각해보기' title, '한 가지 재료를 달거나 짜거나 새콤하게 변형할 방법 생각해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 2 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M132,맛,재료,변형' tags FROM dual
    UNION ALL
    SELECT 'M133' seed_code, '음식 포장에서 처음 보는 원재료 하나 찾아 알아보기' title, '음식 포장에서 처음 보는 원재료 하나 찾아 알아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 1 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 1 cost_level,
           'M133,원재료,관찰,정보' tags FROM dual
    UNION ALL
    SELECT 'M134' seed_code, '진열대에서 포장 디자인만 보고 가장 궁금한 음식 하나 골라보기' title, '진열대에서 포장 디자인만 보고 가장 궁금한 음식 하나 골라보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 3 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 1 cost_level,
           'M134,패키지,선택,음식' tags FROM dual
    UNION ALL
    SELECT 'M135' seed_code, '평소 사용하지 않던 조리도구 하나의 사용법 알아보기' title, '평소 사용하지 않던 조리도구 하나의 사용법 알아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 2 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           1 novelty_level, 'PRACTICE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M135,조리도구,학습' tags FROM dual
    UNION ALL
    SELECT 'M136' seed_code, '같은 종류 음식 두 개의 향이나 식감을 비교해보기' title, '같은 종류 음식 두 개의 향이나 식감을 비교해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 1 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 1 cost_level,
           'M136,비교,식감,맛' tags FROM dual
    UNION ALL
    SELECT 'M137' seed_code, '집에 있는 재료로 나만의 간단한 소스 조합 생각해보기' title, '집에 있는 재료로 나만의 간단한 소스 조합 생각해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 2 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M137,소스,조합,요리' tags FROM dual
    UNION ALL
    SELECT 'M138' seed_code, '다른 나라에서 흔히 먹는 아침 메뉴 하나 찾아보기' title, '다른 나라에서 흔히 먹는 아침 메뉴 하나 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 1 cost_level,
           'M138,해외,아침,음식문화' tags FROM dual
    UNION ALL
    SELECT 'M139' seed_code, '주변 사람에게 어릴 때 좋아했던 음식 하나 물어보기' title, '주변 사람에게 어릴 때 좋아했던 음식 하나 물어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'FOOD' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           1 novelty_level, 'ASK' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 1 cost_level,
           'M139,추억,음식,대화' tags FROM dual
    UNION ALL
    SELECT 'M140' seed_code, '오늘 날짜에 과거 어떤 일이 있었는지 하나 찾아보기' title, '오늘 날짜에 과거 어떤 일이 있었는지 하나 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M140,역사,날짜,탐색' tags FROM dual
    UNION ALL
    SELECT 'M141' seed_code, '평소 헷갈렸던 단어 하나의 정확한 뜻 알아보기' title, '평소 헷갈렸던 단어 하나의 정확한 뜻 알아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'PRACTICE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M141,단어,사전,학습' tags FROM dual
    UNION ALL
    SELECT 'M142' seed_code, '일상에서 원리를 잘 모르고 사용하는 물건 하나 찾아보기' title, '일상에서 원리를 잘 모르고 사용하는 물건 하나 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M142,원리,사물,호기심' tags FROM dual
    UNION ALL
    SELECT 'M143' seed_code, '무작위 국가 하나를 골라 수도와 특징 하나 알아보기' title, '무작위 국가 하나를 골라 수도와 특징 하나 알아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 3 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M143,국가,지리,랜덤' tags FROM dual
    UNION ALL
    SELECT 'M144' seed_code, '새로 알게 된 정보를 질문 세 개로 바꿔보기' title, '새로 알게 된 정보를 질문 세 개로 바꿔보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'CREATE' action_type,
           2 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M144,질문,학습,정리' tags FROM dual
    UNION ALL
    SELECT 'M145' seed_code, '검색하지 않고 아는 내용을 먼저 적은 뒤 실제 정보와 비교해보기' title, '검색하지 않고 아는 내용을 먼저 적은 뒤 실제 정보와 비교해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'PRACTICE' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M145,기억,비교,학습' tags FROM dual
    UNION ALL
    SELECT 'M146' seed_code, '평소 궁금했지만 검색하지 않았던 질문 하나 해결해보기' title, '평소 궁금했지만 검색하지 않았던 질문 하나 해결해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M146,궁금증,검색,지식' tags FROM dual
    UNION ALL
    SELECT 'M147' seed_code, '주변 시설물 하나가 왜 그런 형태인지 이유를 추측해보기' title, '주변 시설물 하나가 왜 그런 형태인지 이유를 추측해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M147,시설,추론,관찰' tags FROM dual
    UNION ALL
    SELECT 'M148' seed_code, '새로운 숫자 암기법 하나를 시험해보기' title, '새로운 숫자 암기법 하나를 시험해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'PRACTICE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M148,기억,숫자,방법' tags FROM dual
    UNION ALL
    SELECT 'M149' seed_code, '익숙한 제품 하나가 처음 만들어진 배경 알아보기' title, '익숙한 제품 하나가 처음 만들어진 배경 알아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 3 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M149,제품,역사,탐색' tags FROM dual
    UNION ALL
    SELECT 'M150' seed_code, '오늘 알게 된 사실을 퀴즈 한 문제로 만들어보기' title, '오늘 알게 된 사실을 퀴즈 한 문제로 만들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M150,퀴즈,지식,창작' tags FROM dual
    UNION ALL
    SELECT 'M151' seed_code, '평소 사용하던 기능 하나를 설명서 없이 다른 방법으로 실행해보기' title, '평소 사용하던 기능 하나를 설명서 없이 다른 방법으로 실행해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'PRACTICE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M151,문제해결,기능,실습' tags FROM dual
    UNION ALL
    SELECT 'M152' seed_code, '익숙한 단어 하나의 어원이나 유래 알아보기' title, '익숙한 단어 하나의 어원이나 유래 알아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'LEARNING' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M152,어원,언어,탐색' tags FROM dual
    UNION ALL
    SELECT 'M153' seed_code, '지인에게 최근 도움이 되었던 것 하나 알려주기' title, '지인에게 최근 도움이 되었던 것 하나 알려주기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           1 novelty_level, 'CONNECT' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M153,공유,정보,관계' tags FROM dual
    UNION ALL
    SELECT 'M154' seed_code, '주변 사람에게 오늘 있었던 작은 좋은 일 하나 물어보기' title, '주변 사람에게 오늘 있었던 작은 좋은 일 하나 물어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           1 novelty_level, 'ASK' action_type,
           0 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M154,질문,일상,대화' tags FROM dual
    UNION ALL
    SELECT 'M155' seed_code, '오래된 사진 한 장을 지인에게 보내 추억 하나 이야기해보기' title, '오래된 사진 한 장을 지인에게 보내 추억 하나 이야기해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           2 novelty_level, 'CONNECT' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M155,추억,사진,관계' tags FROM dual
    UNION ALL
    SELECT 'M156' seed_code, '다른 사람에게 내가 잘 모르는 취미 하나 설명해달라고 해보기' title, '다른 사람에게 내가 잘 모르는 취미 하나 설명해달라고 해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           2 novelty_level, 'ASK' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M156,취미,질문,학습' tags FROM dual
    UNION ALL
    SELECT 'M157' seed_code, '누군가가 전에 해준 도움을 떠올려 다시 한번 고맙다고 말하기' title, '누군가가 전에 해준 도움을 떠올려 다시 한번 고맙다고 말하기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           1 novelty_level, 'CONNECT' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M157,감사,회상,관계' tags FROM dual
    UNION ALL
    SELECT 'M158' seed_code, '직원에게 가장 인기 있는 상품이 무엇인지 물어보기' title, '직원에게 가장 인기 있는 상품이 무엇인지 물어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 3 difficulty, 5 estimated_minutes,
           1 indoor_outdoor, 1 social_level, 0 activity_level,
           2 novelty_level, 'ASK' action_type,
           0 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M158,직원,질문,정보' tags FROM dual
    UNION ALL
    SELECT 'M159' seed_code, '평소 대화가 짧았던 사람에게 질문 하나 더 이어가보기' title, '평소 대화가 짧았던 사람에게 질문 하나 더 이어가보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           2 novelty_level, 'CONNECT' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M159,대화,관심,관계' tags FROM dual
    UNION ALL
    SELECT 'M160' seed_code, '지인에게 최근 가장 많이 사용하는 앱 하나 물어보기' title, '지인에게 최근 가장 많이 사용하는 앱 하나 물어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           1 novelty_level, 'ASK' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M160,앱,취향,질문' tags FROM dual
    UNION ALL
    SELECT 'M161' seed_code, '친구와 서로 하나씩 임의의 질문을 주고받아보기' title, '친구와 서로 하나씩 임의의 질문을 주고받아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           2 novelty_level, 'CONNECT' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M161,질문,게임,대화' tags FROM dual
    UNION ALL
    SELECT 'M162' seed_code, '주변 사람에게 가보고 싶은 장소 하나를 물어보기' title, '주변 사람에게 가보고 싶은 장소 하나를 물어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           2 novelty_level, 'ASK' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M162,장소,추천,대화' tags FROM dual
    UNION ALL
    SELECT 'M163' seed_code, '상대가 전에 말했던 일을 기억해 후속 질문 하나 해보기' title, '상대가 전에 말했던 일을 기억해 후속 질문 하나 해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           1 novelty_level, 'CONNECT' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M163,기억,관심,대화' tags FROM dual
    UNION ALL
    SELECT 'M164' seed_code, '나와 취향이 다른 사람에게 좋아하는 이유를 하나 물어보기' title, '나와 취향이 다른 사람에게 좋아하는 이유를 하나 물어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'SOCIAL' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, 1 social_level, 0 activity_level,
           2 novelty_level, 'ASK' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M164,취향,관점,질문' tags FROM dual
    UNION ALL
    SELECT 'M165' seed_code, '주변에서 가장 오래되어 보이는 물건이나 건물 하나 찾아보기' title, '주변에서 가장 오래되어 보이는 물건이나 건물 하나 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M165,시간,거리,관찰' tags FROM dual
    UNION ALL
    SELECT 'M166' seed_code, '평소 지나가기만 했던 작은 공공 공간에 잠시 머물러보기' title, '평소 지나가기만 했던 작은 공공 공간에 잠시 머물러보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 15 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           0 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M166,공간,탐색,휴식' tags FROM dual
    UNION ALL
    SELECT 'M167' seed_code, '거리에서 서로 다른 글꼴 세 가지 찾아보기' title, '거리에서 서로 다른 글꼴 세 가지 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M167,타이포,거리,관찰' tags FROM dual
    UNION ALL
    SELECT 'M168' seed_code, '가까운 곳에서 이름만 알고 가보지 않았던 장소 하나 방문해보기' title, '가까운 곳에서 이름만 알고 가보지 않았던 장소 하나 방문해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 3 difficulty, 15 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           0 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M168,방문,장소,탐험' tags FROM dual
    UNION ALL
    SELECT 'M169' seed_code, '하늘을 3분간 보고 구름이나 빛의 변화 관찰하기' title, '하늘을 3분간 보고 구름이나 빛의 변화 관찰하기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M169,하늘,빛,관찰' tags FROM dual
    UNION ALL
    SELECT 'M170' seed_code, '길에서 발견한 세 가지 요소로 짧은 이야기 만들어보기' title, '길에서 발견한 세 가지 요소로 짧은 이야기 만들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M170,거리,이야기,창작' tags FROM dual
    UNION ALL
    SELECT 'M171' seed_code, '같은 거리에서 오래된 것과 새로운 것을 하나씩 찾아보기' title, '같은 거리에서 오래된 것과 새로운 것을 하나씩 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M171,대비,거리,관찰' tags FROM dual
    UNION ALL
    SELECT 'M172' seed_code, '평소 반대 방향으로 5분간 이동한 뒤 주변 둘러보기' title, '평소 반대 방향으로 5분간 이동한 뒤 주변 둘러보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 15 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           0 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M172,방향,탐색,이동' tags FROM dual
    UNION ALL
    SELECT 'M173' seed_code, '주변에서 사람들이 가장 자주 멈추는 장소 찾아보기' title, '주변에서 사람들이 가장 자주 멈추는 장소 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M173,사람,공간,관찰' tags FROM dual
    UNION ALL
    SELECT 'M174' seed_code, '평범한 거리 풍경에서 대칭 구도를 찾아 사진 찍어보기' title, '평범한 거리 풍경에서 대칭 구도를 찾아 사진 찍어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M174,대칭,사진,거리' tags FROM dual
    UNION ALL
    SELECT 'M175' seed_code, '밖에서 평소 맡지 못했던 냄새 하나 찾아보기' title, '밖에서 평소 맡지 못했던 냄새 하나 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 2 difficulty, 10 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M175,후각,거리,감각' tags FROM dual
    UNION ALL
    SELECT 'M176' seed_code, '가까운 목적지까지 지도 없이 익숙하지 않은 경로로 가보기' title, '가까운 목적지까지 지도 없이 익숙하지 않은 경로로 가보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'OUTDOOR' category, 3 difficulty, 15 estimated_minutes,
           1 indoor_outdoor, -1 social_level, 2 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           0 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M176,길찾기,탐색,도전' tags FROM dual
    UNION ALL
    SELECT 'M177' seed_code, '휴대폰에서 사용하지 않는 알림 하나 꺼보기' title, '휴대폰에서 사용하지 않는 알림 하나 꺼보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 1 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'ORGANIZE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M177,알림,디지털,정리' tags FROM dual
    UNION ALL
    SELECT 'M178' seed_code, '자주 사용하는 공간 하나에서 물건 세 개만 남겨보기' title, '자주 사용하는 공간 하나에서 물건 세 개만 남겨보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 2 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           1 novelty_level, 'ORGANIZE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M178,공간,미니멀,정리' tags FROM dual
    UNION ALL
    SELECT 'M179' seed_code, '이메일이나 메시지함에서 필요 없는 항목 다섯 개 정리하기' title, '이메일이나 메시지함에서 필요 없는 항목 다섯 개 정리하기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 1 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'ORGANIZE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M179,메시지,디지털,정리' tags FROM dual
    UNION ALL
    SELECT 'M180' seed_code, '냉장고나 식품 보관 공간 한 구역만 정리해보기' title, '냉장고나 식품 보관 공간 한 구역만 정리해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 2 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           1 novelty_level, 'ORGANIZE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M180,식품,공간,정리' tags FROM dual
    UNION ALL
    SELECT 'M181' seed_code, '하루 동안 자주 찾지만 제자리가 없는 물건 하나 찾아보기' title, '하루 동안 자주 찾지만 제자리가 없는 물건 하나 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 1 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M181,생활,물건,관찰' tags FROM dual
    UNION ALL
    SELECT 'M182' seed_code, '사진 앨범에서 비슷한 사진 다섯 장을 비교해 하나만 남겨보기' title, '사진 앨범에서 비슷한 사진 다섯 장을 비교해 하나만 남겨보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'ORGANIZE' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M182,사진,선택,디지털' tags FROM dual
    UNION ALL
    SELECT 'M183' seed_code, '반복해서 하는 일을 세 단계로 줄여 간단한 순서 만들어보기' title, '반복해서 하는 일을 세 단계로 줄여 간단한 순서 만들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M183,프로세스,효율,정리' tags FROM dual
    UNION ALL
    SELECT 'M184' seed_code, '옷 한 종류만 골라 사용 빈도 순서대로 정리해보기' title, '옷 한 종류만 골라 사용 빈도 순서대로 정리해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 2 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           1 novelty_level, 'ORGANIZE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M184,옷,빈도,정리' tags FROM dual
    UNION ALL
    SELECT 'M185' seed_code, '자주 쓰는 앱 중 첫 화면에 있을 필요 없는 앱 하나 찾아보기' title, '자주 쓰는 앱 중 첫 화면에 있을 필요 없는 앱 하나 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 1 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           0 comfort_zone_distance, 0 cost_level,
           'M185,앱,관찰,디지털' tags FROM dual
    UNION ALL
    SELECT 'M186' seed_code, '메모 목록에서 오래된 메모 세 개를 확인하고 정리하기' title, '메모 목록에서 오래된 메모 세 개를 확인하고 정리하기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'ORGANIZE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M186,메모,디지털,정리' tags FROM dual
    UNION ALL
    SELECT 'M187' seed_code, '자주 잊는 물건 하나를 잊지 않게 만드는 새로운 방법 생각해보기' title, '자주 잊는 물건 하나를 잊지 않게 만드는 새로운 방법 생각해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M187,습관,아이디어,생활' tags FROM dual
    UNION ALL
    SELECT 'M188' seed_code, '물건을 크기나 종류가 아닌 사용 시점 기준으로 재분류해보기' title, '물건을 크기나 종류가 아닌 사용 시점 기준으로 재분류해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'ORGANIZING' category, 2 difficulty, 10 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 1 activity_level,
           2 novelty_level, 'ORGANIZE' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M188,분류,생활,실험' tags FROM dual
    UNION ALL
    SELECT 'M189' seed_code, '평소 보지 않던 나라의 광고 영상 하나 찾아보기' title, '평소 보지 않던 나라의 광고 영상 하나 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M189,광고,해외,문화' tags FROM dual
    UNION ALL
    SELECT 'M190' seed_code, '영화나 게임의 배경음악만 따로 한 곡 들어보기' title, '영화나 게임의 배경음악만 따로 한 곡 들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'LISTEN' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M190,OST,음악,콘텐츠' tags FROM dual
    UNION ALL
    SELECT 'M191' seed_code, '익숙한 동화나 이야기가 다른 나라에서는 어떻게 전해지는지 찾아보기' title, '익숙한 동화나 이야기가 다른 나라에서는 어떻게 전해지는지 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M191,이야기,해외,문화' tags FROM dual
    UNION ALL
    SELECT 'M192' seed_code, '좋아하는 작품의 포스터를 보고 사용된 색 세 가지 분석해보기' title, '좋아하는 작품의 포스터를 보고 사용된 색 세 가지 분석해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M192,포스터,색,콘텐츠' tags FROM dual
    UNION ALL
    SELECT 'M193' seed_code, '한 번도 본 적 없는 스포츠나 경기 영상 5분 보기' title, '한 번도 본 적 없는 스포츠나 경기 영상 5분 보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 3 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M193,스포츠,영상,탐색' tags FROM dual
    UNION ALL
    SELECT 'M194' seed_code, '평소 듣던 노래의 다른 편곡이나 라이브 버전 들어보기' title, '평소 듣던 노래의 다른 편곡이나 라이브 버전 들어보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'LISTEN' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M194,편곡,라이브,음악' tags FROM dual
    UNION ALL
    SELECT 'M195' seed_code, '다른 세대에서 유행했던 콘텐츠 하나 찾아보기' title, '다른 세대에서 유행했던 콘텐츠 하나 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M195,세대,유행,문화' tags FROM dual
    UNION ALL
    SELECT 'M196' seed_code, '영화·게임·드라마 속 배경 공간 하나를 유심히 관찰해보기' title, '영화·게임·드라마 속 배경 공간 하나를 유심히 관찰해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           1 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 1 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M196,공간,콘텐츠,관찰' tags FROM dual
    UNION ALL
    SELECT 'M197' seed_code, '알고 있는 이야기 하나의 결말을 다르게 한 문장으로 바꿔보기' title, '알고 있는 이야기 하나의 결말을 다르게 한 문장으로 바꿔보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 2 difficulty, 5 estimated_minutes,
           -1 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'CREATE' action_type,
           2 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M197,이야기,결말,창작' tags FROM dual
    UNION ALL
    SELECT 'M198' seed_code, '평소 관심 없던 공연 장르 하나의 대표 영상 찾아보기' title, '평소 관심 없던 공연 장르 하나의 대표 영상 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 3 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M198,공연,장르,탐색' tags FROM dual
    UNION ALL
    SELECT 'M199' seed_code, '익숙한 캐릭터나 로고에서 평소 몰랐던 특징 하나 찾아보기' title, '익숙한 캐릭터나 로고에서 평소 몰랐던 특징 하나 찾아보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'OBSERVE' action_type,
           1 creativity_level, 2 unpredictability_level,
           1 comfort_zone_distance, 0 cost_level,
           'M199,캐릭터,로고,관찰' tags FROM dual
    UNION ALL
    SELECT 'M200' seed_code, '한 작품이 다른 매체로 각색된 사례 하나 찾아 비교해보기' title, '한 작품이 다른 매체로 각색된 사례 하나 찾아 비교해보기 완료 후 느낀 점을 짧게 기록해 보세요.' description,
           'CULTURE' category, 2 difficulty, 5 estimated_minutes,
           0 indoor_outdoor, -1 social_level, 0 activity_level,
           2 novelty_level, 'EXPLORE' action_type,
           1 creativity_level, 2 unpredictability_level,
           2 comfort_zone_distance, 0 cost_level,
           'M200,각색,콘텐츠,비교' tags FROM dual
) source
ON (target.TITLE_NORMALIZED = UPPER(REPLACE(source.title, ' ', '')))
WHEN MATCHED THEN UPDATE SET
    target.TITLE = source.title,
    target.DESCRIPTION = source.description,
    target.CATEGORY = source.category,
    target.DIFFICULTY = source.difficulty,
    target.ESTIMATED_MINUTES = source.estimated_minutes,
    target.INDOOR_OUTDOOR = source.indoor_outdoor,
    target.SOCIAL_LEVEL = source.social_level,
    target.ACTIVITY_LEVEL = source.activity_level,
    target.NOVELTY_LEVEL = source.novelty_level,
    target.ACTION_TYPE = source.action_type,
    target.CREATIVITY_LEVEL = source.creativity_level,
    target.UNPREDICTABILITY_LEVEL = source.unpredictability_level,
    target.COMFORT_ZONE_DISTANCE = source.comfort_zone_distance,
    target.COST_LEVEL = source.cost_level,
    target.TAGS = source.tags,
    target.ENABLED = 'Y',
    target.SOURCE_TYPE = 'BASE',
    target.CONTENT_FINGERPRINT = LOWER(RAWTOHEX(STANDARD_HASH(
        source.title || '|' || source.description, 'SHA256')))
WHEN NOT MATCHED THEN
    INSERT (
        MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY,
        DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL,
        ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL,
        UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS,
        ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT
    ) VALUES (
        MISSION_SEQ.NEXTVAL, source.title, UPPER(REPLACE(source.title, ' ', '')),
        source.description, source.category, source.difficulty, source.estimated_minutes,
        source.indoor_outdoor, source.social_level, source.activity_level,
        source.novelty_level, source.action_type, source.creativity_level,
        source.unpredictability_level, source.comfort_zone_distance,
        source.cost_level, source.tags, 'Y', 'BASE',
        LOWER(RAWTOHEX(STANDARD_HASH(source.title || '|' || source.description, 'SHA256')))
    );

COMMIT;

DECLARE
    object_count NUMBER;
    orphan_count NUMBER;
    table_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_constraints
     WHERE constraint_name = 'FK_MISSION_STATUS_LOG_MISSION';

    SELECT COUNT(*)
      INTO table_count
      FROM user_tables
     WHERE table_name IN ('MISSION', 'MISSION_STATUS_LOG');

    IF object_count = 0 AND table_count = 2 THEN
        EXECUTE IMMEDIATE '
            SELECT COUNT(*)
              FROM MISSION_STATUS_LOG log_row
             WHERE NOT EXISTS (
                   SELECT 1 FROM MISSION mission_row
                    WHERE mission_row.MISSION_ID = log_row.MISSION_ID
             )' INTO orphan_count;

        IF orphan_count = 0 THEN
            EXECUTE IMMEDIATE '
                ALTER TABLE MISSION_STATUS_LOG
                ADD CONSTRAINT FK_MISSION_STATUS_LOG_MISSION
                FOREIGN KEY (MISSION_ID) REFERENCES MISSION (MISSION_ID)';
        END IF;
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_sequences
     WHERE sequence_name = 'MISSION_LLM_GENERATION_SEQ';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE SEQUENCE MISSION_LLM_GENERATION_SEQ
                START WITH 1
                INCREMENT BY 1
                NOCACHE
                NOCYCLE';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tables
     WHERE table_name = 'MISSION_LLM_GENERATION';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE MISSION_LLM_GENERATION (
                GENERATION_ID        NUMBER(19)         NOT NULL,
                USER_ID              NUMBER(19)         NOT NULL,
                COMPLETION_MILESTONE NUMBER(10)         NOT NULL,
                STATUS               VARCHAR2(12 CHAR)  NOT NULL,
                MISSION_ID           NUMBER(19),
                MODEL_NAME           VARCHAR2(100 CHAR),
                ERROR_CODE           VARCHAR2(40 CHAR),
                CREATED_AT           TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
                UPDATED_AT           TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
                CONSTRAINT PK_MISSION_LLM_GENERATION PRIMARY KEY (GENERATION_ID),
                CONSTRAINT UK_MISSION_LLM_USER_MILESTONE UNIQUE (USER_ID, COMPLETION_MILESTONE),
                CONSTRAINT FK_MISSION_LLM_MISSION FOREIGN KEY (MISSION_ID)
                    REFERENCES MISSION (MISSION_ID),
                CONSTRAINT CK_MISSION_LLM_MILESTONE CHECK (
                    COMPLETION_MILESTONE >= 5 AND MOD(COMPLETION_MILESTONE, 5) = 0
                ),
                CONSTRAINT CK_MISSION_LLM_STATUS CHECK (
                    STATUS IN (''PENDING'', ''COMPLETED'', ''FAILED'')
                )
            )';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tables
     WHERE table_name = 'SURVEY_RESPONSE';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE SURVEY_RESPONSE (
                SURVEY_ID         NUMBER(19)    NOT NULL,
                ACTIVITY_LEVEL    VARCHAR2(10)  NOT NULL,
                SOCIAL_ACTIVITY   VARCHAR2(10)  NOT NULL,
                NOVELTY_TOLERANCE VARCHAR2(10)  NOT NULL,
                ENERGY_LEVEL      VARCHAR2(10)  NOT NULL,
                CREATED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP NOT NULL,
                CONSTRAINT PK_SURVEY_RESPONSE PRIMARY KEY (SURVEY_ID),
                CONSTRAINT CK_SURVEY_ACTIVITY
                    CHECK (ACTIVITY_LEVEL IN (''INDOOR'', ''MIXED'', ''OUTDOOR'')),
                CONSTRAINT CK_SURVEY_SOCIAL
                    CHECK (SOCIAL_ACTIVITY IN (''LOW'', ''MEDIUM'', ''HIGH'')),
                CONSTRAINT CK_SURVEY_NOVELTY
                    CHECK (NOVELTY_TOLERANCE IN (''LOW'', ''MEDIUM'', ''HIGH'')),
                CONSTRAINT CK_SURVEY_ENERGY
                    CHECK (ENERGY_LEVEL IN (''LOW'', ''MEDIUM'', ''HIGH''))
            )';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_sequences
     WHERE sequence_name = 'NOVELTY_USER_SEQ';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE SEQUENCE NOVELTY_USER_SEQ
                START WITH 1
                INCREMENT BY 1
                NOCACHE
                NOCYCLE';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tables
     WHERE table_name = 'NOVELTY_USER';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE NOVELTY_USER (
                USER_ID             NUMBER(19)        NOT NULL,
                USER_KEY_HASH       VARCHAR2(64 CHAR) NOT NULL,
                LOGIN_ID_NORMALIZED VARCHAR2(20 CHAR),
                PASSWORD_HASH       VARCHAR2(255 CHAR),
                NICKNAME            VARCHAR2(36 CHAR) NOT NULL,
                NICKNAME_NORMALIZED VARCHAR2(36 CHAR) NOT NULL,
                CREATED_AT          TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
                UPDATED_AT          TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
                LAST_SEEN_AT        TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
                CONSTRAINT PK_NOVELTY_USER PRIMARY KEY (USER_ID),
                CONSTRAINT UQ_NOVELTY_USER_KEY_HASH UNIQUE (USER_KEY_HASH),
                CONSTRAINT UQ_NOVELTY_USER_LOGIN_ID UNIQUE (LOGIN_ID_NORMALIZED),
                CONSTRAINT UQ_NOVELTY_USER_NICKNAME UNIQUE (NICKNAME_NORMALIZED),
                CONSTRAINT CK_NOVELTY_USER_ACCOUNT_PAIR CHECK (
                    (LOGIN_ID_NORMALIZED IS NULL AND PASSWORD_HASH IS NULL)
                    OR (LOGIN_ID_NORMALIZED IS NOT NULL AND PASSWORD_HASH IS NOT NULL)
                ),
                CONSTRAINT CK_NOVELTY_USER_LOGIN_ID CHECK (
                    LOGIN_ID_NORMALIZED IS NULL
                    OR (LENGTH(LOGIN_ID_NORMALIZED) BETWEEN 4 AND 20
                        AND TRANSLATE(
                            LOGIN_ID_NORMALIZED,
                            ''~abcdefghijklmnopqrstuvwxyz0123456789_'',
                            ''~''
                        ) IS NULL)
                ),
                CONSTRAINT CK_NOVELTY_USER_NICKNAME_LENGTH
                    CHECK (LENGTH(NICKNAME) BETWEEN 1 AND 12)
            )';
    END IF;
END;
/

DECLARE
    column_count NUMBER;
    constraint_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO column_count FROM user_tab_columns
     WHERE table_name = 'NOVELTY_USER' AND column_name = 'LOGIN_ID_NORMALIZED';
    IF column_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE NOVELTY_USER ADD LOGIN_ID_NORMALIZED VARCHAR2(20 CHAR)';
    END IF;

    SELECT COUNT(*) INTO column_count FROM user_tab_columns
     WHERE table_name = 'NOVELTY_USER' AND column_name = 'PASSWORD_HASH';
    IF column_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE NOVELTY_USER ADD PASSWORD_HASH VARCHAR2(255 CHAR)';
    END IF;

    SELECT COUNT(*) INTO constraint_count FROM user_constraints
     WHERE constraint_name = 'UQ_NOVELTY_USER_LOGIN_ID';
    IF constraint_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE NOVELTY_USER ADD CONSTRAINT UQ_NOVELTY_USER_LOGIN_ID UNIQUE (LOGIN_ID_NORMALIZED)';
    END IF;

    SELECT COUNT(*) INTO constraint_count FROM user_constraints
     WHERE constraint_name = 'CK_NOVELTY_USER_ACCOUNT_PAIR';
    IF constraint_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE NOVELTY_USER ADD CONSTRAINT CK_NOVELTY_USER_ACCOUNT_PAIR CHECK ((LOGIN_ID_NORMALIZED IS NULL AND PASSWORD_HASH IS NULL) OR (LOGIN_ID_NORMALIZED IS NOT NULL AND PASSWORD_HASH IS NOT NULL))';
    END IF;

    SELECT COUNT(*) INTO constraint_count FROM user_constraints
     WHERE constraint_name = 'CK_NOVELTY_USER_LOGIN_ID';
    IF constraint_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE NOVELTY_USER ADD CONSTRAINT CK_NOVELTY_USER_LOGIN_ID CHECK (LOGIN_ID_NORMALIZED IS NULL OR (LENGTH(LOGIN_ID_NORMALIZED) BETWEEN 4 AND 20 AND TRANSLATE(LOGIN_ID_NORMALIZED, ''~abcdefghijklmnopqrstuvwxyz0123456789_'', ''~'') IS NULL))';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_sequences
     WHERE sequence_name = 'NICKNAME_BANNED_WORD_SEQ';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE SEQUENCE NICKNAME_BANNED_WORD_SEQ
                START WITH 1
                INCREMENT BY 1
                NOCACHE
                NOCYCLE';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tables
     WHERE table_name = 'NICKNAME_BANNED_WORD';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE NICKNAME_BANNED_WORD (
                BANNED_WORD_ID NUMBER(19)        NOT NULL,
                WORD_NORMALIZED VARCHAR2(36 CHAR) NOT NULL,
                ACTIVE          CHAR(1) DEFAULT ''Y'' NOT NULL,
                CREATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
                CONSTRAINT PK_NICKNAME_BANNED_WORD PRIMARY KEY (BANNED_WORD_ID),
                CONSTRAINT UQ_NICKNAME_BANNED_WORD UNIQUE (WORD_NORMALIZED),
                CONSTRAINT CK_NICKNAME_BANNED_ACTIVE CHECK (ACTIVE IN (''Y'', ''N''))
            )';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tab_columns
     WHERE table_name = 'SURVEY_RESPONSE'
       AND column_name = 'USER_ID';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE SURVEY_RESPONSE
            ADD (USER_ID NUMBER(19))';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tab_columns
     WHERE table_name = 'SURVEY_RESPONSE'
       AND column_name = 'SUBMISSION_KEY';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE SURVEY_RESPONSE
            ADD (SUBMISSION_KEY VARCHAR2(64 CHAR))';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tab_columns
     WHERE table_name = 'SURVEY_RESPONSE'
       AND column_name = 'EXECUTION_STYLE';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE SURVEY_RESPONSE
            ADD (EXECUTION_STYLE VARCHAR2(16 CHAR))';
    END IF;
END;
/

-- PERSONALITY_V2_PHASE1_START

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tab_columns
     WHERE table_name = 'SURVEY_RESPONSE'
       AND column_name = 'PHYSICAL_ACTIVITY_LEVEL';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE SURVEY_RESPONSE
            ADD (PHYSICAL_ACTIVITY_LEVEL VARCHAR2(10 CHAR))';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tab_columns
     WHERE table_name = 'SURVEY_RESPONSE'
       AND column_name = 'ANALYSIS_MODE';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE SURVEY_RESPONSE
            ADD (ANALYSIS_MODE VARCHAR2(12 CHAR))';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tab_columns
     WHERE table_name = 'SURVEY_RESPONSE'
       AND column_name = 'ANALYSIS_VERSION';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE SURVEY_RESPONSE
            ADD (ANALYSIS_VERSION VARCHAR2(24 CHAR))';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
    current_length NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tab_columns
     WHERE table_name = 'USER_PERSONALITY_PROFILE'
       AND column_name = 'ANALYSIS_VERSION';

    IF object_count > 0 THEN
        SELECT char_length
          INTO current_length
          FROM user_tab_columns
         WHERE table_name = 'USER_PERSONALITY_PROFILE'
           AND column_name = 'ANALYSIS_VERSION';

        IF current_length < 24 THEN
            EXECUTE IMMEDIATE '
                ALTER TABLE USER_PERSONALITY_PROFILE
                MODIFY (ANALYSIS_VERSION VARCHAR2(24 CHAR))';
        END IF;
    END IF;
END;
/

DECLARE
    is_nullable VARCHAR2(1);
BEGIN
    SELECT nullable
      INTO is_nullable
      FROM user_tab_columns
     WHERE table_name = 'SURVEY_RESPONSE'
       AND column_name = 'ENERGY_LEVEL';

    IF is_nullable = 'N' THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE SURVEY_RESPONSE
            MODIFY (ENERGY_LEVEL NULL)';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_constraints
     WHERE constraint_name = 'FK_SURVEY_RESPONSE_USER';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE SURVEY_RESPONSE
            ADD CONSTRAINT FK_SURVEY_RESPONSE_USER
                FOREIGN KEY (USER_ID)
                REFERENCES NOVELTY_USER (USER_ID)';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_constraints
     WHERE table_name = 'SURVEY_RESPONSE'
       AND constraint_name = 'UQ_SURVEY_SUBMISSION_KEY';

    IF object_count > 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE SURVEY_RESPONSE
            DROP CONSTRAINT UQ_SURVEY_SUBMISSION_KEY';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_constraints
     WHERE table_name = 'SURVEY_RESPONSE'
       AND constraint_name = 'UQ_SURVEY_USER_SUBMISSION';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE SURVEY_RESPONSE
            ADD CONSTRAINT UQ_SURVEY_USER_SUBMISSION
                UNIQUE (USER_ID, SUBMISSION_KEY)';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_constraints
     WHERE constraint_name = 'CK_SURVEY_EXECUTION_STYLE';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE SURVEY_RESPONSE
            ADD CONSTRAINT CK_SURVEY_EXECUTION_STYLE
                CHECK (EXECUTION_STYLE IN (
                    ''PLANNED'',
                    ''FLEXIBLE'',
                    ''SPONTANEOUS''
                ))';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_constraints
     WHERE table_name = 'SURVEY_RESPONSE'
       AND constraint_name = 'CK_SURVEY_PHYSICAL_ACTIVITY';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE SURVEY_RESPONSE
            ADD CONSTRAINT CK_SURVEY_PHYSICAL_ACTIVITY
                CHECK (
                    PHYSICAL_ACTIVITY_LEVEL IS NULL
                    OR PHYSICAL_ACTIVITY_LEVEL IN (''LOW'', ''MEDIUM'', ''HIGH'')
                )';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_constraints
     WHERE table_name = 'SURVEY_RESPONSE'
       AND constraint_name = 'CK_SURVEY_ANALYSIS_MODE';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE SURVEY_RESPONSE
            ADD CONSTRAINT CK_SURVEY_ANALYSIS_MODE
                CHECK (
                    ANALYSIS_MODE IS NULL
                    OR ANALYSIS_MODE IN (''INITIAL'', ''REANALYSIS'')
                )';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_constraints
     WHERE table_name = 'SURVEY_RESPONSE'
       AND constraint_name = 'CK_SURVEY_ANALYSIS_VERSION';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE SURVEY_RESPONSE
            ADD CONSTRAINT CK_SURVEY_ANALYSIS_VERSION
                CHECK (
                    ANALYSIS_VERSION IS NULL
                    OR ANALYSIS_VERSION = ''PERSONALITY_V2''
                )';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_constraints
     WHERE table_name = 'SURVEY_RESPONSE'
       AND constraint_name = 'CK_SURVEY_V2_REQUIRED_FIELDS';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE SURVEY_RESPONSE
            ADD CONSTRAINT CK_SURVEY_V2_REQUIRED_FIELDS
                CHECK (
                    ANALYSIS_VERSION IS NULL
                    OR (
                        ANALYSIS_VERSION = ''PERSONALITY_V2''
                        AND USER_ID IS NOT NULL
                        AND SUBMISSION_KEY IS NOT NULL
                        AND PHYSICAL_ACTIVITY_LEVEL IS NOT NULL
                        AND EXECUTION_STYLE IS NOT NULL
                        AND ANALYSIS_MODE IS NOT NULL
                        AND ENERGY_LEVEL IS NULL
                    )
                )';
    END IF;
END;
/

-- PERSONALITY_V2_PHASE1_END

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_indexes
     WHERE index_name = 'IX_SURVEY_RESPONSE_USER';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE INDEX IX_SURVEY_RESPONSE_USER
                ON SURVEY_RESPONSE (USER_ID)';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tables
     WHERE table_name = 'USER_PERSONALITY_PROFILE';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE USER_PERSONALITY_PROFILE (
                USER_ID          NUMBER(19)        NOT NULL,
                PERSONALITY_CODE VARCHAR2(32 CHAR) NOT NULL,
                ACTIVITY_SCORE   NUMBER(1)         NOT NULL,
                SOCIAL_SCORE     NUMBER(1)         NOT NULL,
                NOVELTY_SCORE    NUMBER(1)         NOT NULL,
                PHYSICAL_ACTIVITY_SCORE NUMBER(1) DEFAULT 0 NOT NULL,
                COMPLETED_MISSION_COUNT NUMBER(10) DEFAULT 0 NOT NULL,
                EXECUTION_STYLE  VARCHAR2(16 CHAR) NOT NULL,
                SOURCE_SURVEY_ID NUMBER(19)        NOT NULL,
                ANALYSIS_VERSION VARCHAR2(24 CHAR) NOT NULL,
                ANALYZED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
                UPDATED_AT       TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
                CONSTRAINT PK_USER_PERSONALITY_PROFILE PRIMARY KEY (USER_ID),
                CONSTRAINT FK_USER_PERSONALITY_USER
                    FOREIGN KEY (USER_ID)
                    REFERENCES NOVELTY_USER (USER_ID)
                    ON DELETE CASCADE,
                CONSTRAINT FK_USER_PERSONALITY_SURVEY
                    FOREIGN KEY (SOURCE_SURVEY_ID)
                    REFERENCES SURVEY_RESPONSE (SURVEY_ID),
                CONSTRAINT CK_USER_PERSONALITY_CODE
                    CHECK (PERSONALITY_CODE IN (
                        ''QUIET_FOCUSER'',
                        ''COZY_EXPLORER'',
                        ''WARM_HOST'',
                        ''FLEXIBLE_INDEPENDENT'',
                        ''BALANCED_COORDINATOR'',
                        ''OPEN_CONNECTOR'',
                        ''SOLO_EXPLORER'',
                        ''FREE_PIONEER'',
                        ''ACTIVE_CONNECTOR''
                    )),
                CONSTRAINT CK_USER_ACTIVITY_SCORE
                    CHECK (ACTIVITY_SCORE IN (-1, 0, 1)),
                CONSTRAINT CK_USER_SOCIAL_SCORE
                    CHECK (SOCIAL_SCORE IN (-1, 0, 1)),
                CONSTRAINT CK_USER_NOVELTY_SCORE
                    CHECK (NOVELTY_SCORE IN (0, 1, 2)),
                CONSTRAINT CK_USER_PHYSICAL_ACTIVITY
                    CHECK (PHYSICAL_ACTIVITY_SCORE IN (0, 1, 2)),
                CONSTRAINT CK_USER_COMPLETED_MISSION_COUNT
                    CHECK (COMPLETED_MISSION_COUNT >= 0),
                CONSTRAINT CK_USER_EXECUTION_STYLE
                    CHECK (EXECUTION_STYLE IN (
                        ''PLANNED'',
                        ''FLEXIBLE'',
                        ''SPONTANEOUS''
                    ))
            )';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tables
     WHERE table_name = 'USER_PROFILE_INTEREST';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE USER_PROFILE_INTEREST (
                USER_ID      NUMBER(19)        NOT NULL,
                INTEREST_CODE VARCHAR2(20 CHAR) NOT NULL,
                CONSTRAINT PK_USER_PROFILE_INTEREST
                    PRIMARY KEY (USER_ID, INTEREST_CODE),
                CONSTRAINT FK_USER_PROFILE_INTEREST_USER
                    FOREIGN KEY (USER_ID)
                    REFERENCES NOVELTY_USER (USER_ID)
                    ON DELETE CASCADE,
                CONSTRAINT CK_USER_PROFILE_INTEREST_CODE
                    CHECK (INTEREST_CODE IN (
                        ''MOVEMENT'',
                        ''CREATIVE'',
                        ''FOOD'',
                        ''LEARNING'',
                        ''SOCIAL'',
                        ''OUTDOOR'',
                        ''ORGANIZING'',
                        ''CULTURE''
                    ))
            )';
    END IF;
END;
/

MERGE INTO NICKNAME_BANNED_WORD target
USING (
    SELECT TO_CHAR(UNISTR('\AD00\B9AC\C790')) AS word_normalized FROM dual UNION ALL
    SELECT TO_CHAR(UNISTR('\C6B4\C601\C790')) FROM dual UNION ALL
    SELECT 'ADMIN' FROM dual UNION ALL
    SELECT 'ADMINISTRATOR' FROM dual UNION ALL
    SELECT TO_CHAR(UNISTR('\C528\BC1C')) FROM dual UNION ALL
    SELECT TO_CHAR(UNISTR('\C2DC\BC1C')) FROM dual UNION ALL
    SELECT TO_CHAR(UNISTR('\AC1C\C0C8\B07C')) FROM dual UNION ALL
    SELECT TO_CHAR(UNISTR('\BCD1\C2E0')) FROM dual UNION ALL
    SELECT TO_CHAR(UNISTR('\C9C0\B784')) FROM dual
) source
ON (target.WORD_NORMALIZED = source.word_normalized)
WHEN NOT MATCHED THEN
    INSERT (
        BANNED_WORD_ID,
        WORD_NORMALIZED,
        ACTIVE,
        CREATED_AT
    ) VALUES (
        NICKNAME_BANNED_WORD_SEQ.NEXTVAL,
        source.word_normalized,
        'Y',
        CURRENT_TIMESTAMP
    );

COMMIT;

CREATE OR REPLACE TRIGGER TRG_NOVELTY_USER_NICKNAME_BANNED
BEFORE INSERT OR UPDATE OF NICKNAME_NORMALIZED ON NOVELTY_USER
FOR EACH ROW
DECLARE
    banned_word_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO banned_word_count
      FROM NICKNAME_BANNED_WORD
     WHERE ACTIVE = 'Y'
       AND INSTR(:NEW.NICKNAME_NORMALIZED, WORD_NORMALIZED) > 0;

    IF banned_word_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Nickname violates the banned-word policy.');
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tables
     WHERE table_name = 'SURVEY_INTEREST';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE SURVEY_INTEREST (
                SURVEY_ID     NUMBER(19)   NOT NULL,
                INTEREST_CODE VARCHAR2(20) NOT NULL,
                CONSTRAINT PK_SURVEY_INTEREST
                    PRIMARY KEY (SURVEY_ID, INTEREST_CODE),
                CONSTRAINT FK_SURVEY_INTEREST_RESPONSE
                    FOREIGN KEY (SURVEY_ID)
                    REFERENCES SURVEY_RESPONSE (SURVEY_ID)
                    ON DELETE CASCADE,
                CONSTRAINT CK_SURVEY_INTEREST_CODE
                    CHECK (INTEREST_CODE IN (
                        ''MOVEMENT'',
                        ''CREATIVE'',
                        ''FOOD'',
                        ''LEARNING'',
                        ''SOCIAL'',
                        ''OUTDOOR'',
                        ''ORGANIZING'',
                        ''CULTURE''
                    ))
            )';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_sequences
     WHERE sequence_name = 'MISSION_STATUS_LOG_SEQ';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE SEQUENCE MISSION_STATUS_LOG_SEQ
                START WITH 1
                INCREMENT BY 1
                NOCACHE
                NOCYCLE';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_tables
     WHERE table_name = 'MISSION_STATUS_LOG';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE MISSION_STATUS_LOG (
                STATUS_LOG_ID NUMBER(19)                NOT NULL,
                USER_ID       NUMBER(19)                NOT NULL,
                MISSION_ID    NUMBER(19)                NOT NULL,
                CATEGORY      VARCHAR2(20 CHAR)         NOT NULL,
                STATUS        VARCHAR2(12 CHAR)         NOT NULL,
                OCCURRED_AT   TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
                CONSTRAINT PK_MISSION_STATUS_LOG
                    PRIMARY KEY (STATUS_LOG_ID),
                CONSTRAINT FK_MISSION_STATUS_LOG_USER
                    FOREIGN KEY (USER_ID)
                    REFERENCES NOVELTY_USER (USER_ID)
                    ON DELETE CASCADE,
                CONSTRAINT FK_MISSION_STATUS_LOG_MISSION
                    FOREIGN KEY (MISSION_ID)
                    REFERENCES MISSION (MISSION_ID),
                CONSTRAINT CK_MISSION_STATUS_LOG_STATUS
                    CHECK (STATUS IN (
                        ''GENERATED'',
                        ''SHOWN'',
                        ''SELECTED'',
                        ''CANCELLED'',
                        ''COMPLETED''
                    ))
            )';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_indexes
     WHERE index_name = 'IX_MISSION_LOG_USER_OCCURRED';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE INDEX IX_MISSION_LOG_USER_OCCURRED
                ON MISSION_STATUS_LOG (USER_ID, OCCURRED_AT DESC)';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_indexes
     WHERE index_name = 'IX_MISSION_LOG_USER_MISSION';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE INDEX IX_MISSION_LOG_USER_MISSION
                ON MISSION_STATUS_LOG (USER_ID, MISSION_ID, OCCURRED_AT DESC)';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_constraints
     WHERE constraint_name = 'FK_MISSION_LLM_USER';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE MISSION_LLM_GENERATION
            ADD CONSTRAINT FK_MISSION_LLM_USER
            FOREIGN KEY (USER_ID)
            REFERENCES NOVELTY_USER (USER_ID)
            ON DELETE CASCADE';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO object_count FROM user_constraints
     WHERE constraint_name = 'FK_USER_WORLD_OBJECT_USER';
    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE USER_WORLD_OBJECT ADD CONSTRAINT FK_USER_WORLD_OBJECT_USER
            FOREIGN KEY (USER_ID) REFERENCES NOVELTY_USER (USER_ID) ON DELETE CASCADE';
    END IF;
END;
/

-- MISSION_V1_PHASE1_START

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_sequences
     WHERE sequence_name = 'USER_MISSION_SEQ';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE SEQUENCE USER_MISSION_SEQ
                START WITH 1
                INCREMENT BY 1
                NOCACHE
                NOCYCLE';
    END IF;

    SELECT COUNT(*)
      INTO object_count
      FROM user_tables
     WHERE table_name = 'USER_MISSION';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE USER_MISSION (
                USER_MISSION_ID NUMBER(19)                NOT NULL,
                USER_ID         NUMBER(19)                NOT NULL,
                MISSION_ID      NUMBER(19)                NOT NULL,
                STATUS          VARCHAR2(12 CHAR)         NOT NULL,
                AVAILABLE_TIME  VARCHAR2(10 CHAR)         NOT NULL,
                SERVICE_DATE    DATE                      NOT NULL,
                SELECTED_AT     TIMESTAMP WITH TIME ZONE,
                CANCELLED_AT    TIMESTAMP WITH TIME ZONE,
                COMPLETED_AT    TIMESTAMP WITH TIME ZONE,
                CREATED_AT      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
                UPDATED_AT      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
                CONSTRAINT PK_USER_MISSION PRIMARY KEY (USER_MISSION_ID),
                CONSTRAINT UQ_USER_MISSION_DAILY_OFFER
                    UNIQUE (USER_ID, MISSION_ID, SERVICE_DATE),
                CONSTRAINT CK_USER_MISSION_STATUS CHECK (STATUS IN (
                    ''GENERATED'', ''SHOWN'', ''SELECTED'', ''CANCELLED'', ''COMPLETED''
                )),
                CONSTRAINT CK_USER_MISSION_AVAILABLE_TIME CHECK (AVAILABLE_TIME IN (
                    ''QUICK'', ''SHORT'', ''MEDIUM'', ''LONG''
                ))
            )';
    END IF;

    SELECT COUNT(*)
      INTO object_count
      FROM user_indexes
     WHERE index_name = 'IX_USER_MISSION_USER_DATE';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE INDEX IX_USER_MISSION_USER_DATE
                ON USER_MISSION (USER_ID, SERVICE_DATE DESC)';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO object_count FROM user_constraints
     WHERE constraint_name = 'FK_USER_MISSION_USER';
    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE USER_MISSION ADD CONSTRAINT FK_USER_MISSION_USER
            FOREIGN KEY (USER_ID) REFERENCES NOVELTY_USER (USER_ID) ON DELETE CASCADE';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO object_count FROM user_constraints
     WHERE constraint_name = 'FK_USER_MISSION_MISSION';
    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE USER_MISSION ADD CONSTRAINT FK_USER_MISSION_MISSION
            FOREIGN KEY (MISSION_ID) REFERENCES MISSION (MISSION_ID)';
    END IF;
END;
/

DECLARE
    column_count NUMBER;
    PROCEDURE add_column_if_missing(column_name_value VARCHAR2, definition_value VARCHAR2) IS
    BEGIN
        SELECT COUNT(*)
          INTO column_count
          FROM user_tab_columns
         WHERE table_name = 'USER_MISSION'
           AND column_name = column_name_value;

        IF column_count = 0 THEN
            EXECUTE IMMEDIATE 'ALTER TABLE USER_MISSION ADD (' || definition_value || ')';
        END IF;
    END;
BEGIN
    add_column_if_missing('OFFER_BATCH_ID', 'OFFER_BATCH_ID VARCHAR2(64 CHAR)');
    add_column_if_missing('PERSONALITY_DISTANCE', 'PERSONALITY_DISTANCE NUMBER(8,7)');
    add_column_if_missing('RECOMMENDATION_SCORE', 'RECOMMENDATION_SCORE NUMBER(8,7)');
    add_column_if_missing('DAILY_SLOT_NO', 'DAILY_SLOT_NO NUMBER(1)');
    add_column_if_missing('SHOWN_AT', 'SHOWN_AT TIMESTAMP WITH TIME ZONE');
END;
/

DECLARE
    invalid_group_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO invalid_group_count
      FROM (
          SELECT USER_ID, SERVICE_DATE
            FROM USER_MISSION
           WHERE STATUS IN ('SELECTED', 'COMPLETED')
           GROUP BY USER_ID, SERVICE_DATE
          HAVING COUNT(*) > 3
      );

    IF invalid_group_count > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20031,
            'USER_MISSION has more than three active or completed missions for a service date.'
        );
    END IF;

    UPDATE USER_MISSION
       SET OFFER_BATCH_ID = 'LEGACY-' || TO_CHAR(USER_MISSION_ID)
     WHERE OFFER_BATCH_ID IS NULL;

    UPDATE USER_MISSION
       SET SHOWN_AT = CREATED_AT
     WHERE SHOWN_AT IS NULL
       AND STATUS IN ('SHOWN', 'SELECTED', 'CANCELLED', 'COMPLETED');

    MERGE INTO USER_MISSION target
    USING (
        SELECT USER_MISSION_ID,
               ROW_NUMBER() OVER (
                   PARTITION BY USER_ID, SERVICE_DATE
                   ORDER BY NVL(SELECTED_AT, CREATED_AT), USER_MISSION_ID
               ) AS SLOT_NO
          FROM USER_MISSION
         WHERE STATUS IN ('SELECTED', 'COMPLETED')
           AND DAILY_SLOT_NO IS NULL
    ) source
       ON (target.USER_MISSION_ID = source.USER_MISSION_ID)
     WHEN MATCHED THEN
       UPDATE SET target.DAILY_SLOT_NO = source.SLOT_NO;
END;
/

DECLARE
    nullable_value VARCHAR2(1);
BEGIN
    SELECT nullable
      INTO nullable_value
      FROM user_tab_columns
     WHERE table_name = 'USER_MISSION'
       AND column_name = 'OFFER_BATCH_ID';

    IF nullable_value = 'Y' THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE USER_MISSION
            MODIFY (OFFER_BATCH_ID VARCHAR2(64 CHAR) NOT NULL)';
    END IF;
END;
/

DECLARE
    constraint_count NUMBER;
    PROCEDURE add_constraint_if_missing(name_value VARCHAR2, definition_value VARCHAR2) IS
    BEGIN
        SELECT COUNT(*)
          INTO constraint_count
          FROM user_constraints
         WHERE constraint_name = name_value;

        IF constraint_count = 0 THEN
            EXECUTE IMMEDIATE 'ALTER TABLE USER_MISSION ADD CONSTRAINT '
                    || name_value || ' ' || definition_value;
        END IF;
    END;
BEGIN
    add_constraint_if_missing(
        'CK_USER_MISSION_SERVICE_DATE',
        'CHECK (SERVICE_DATE = TRUNC(SERVICE_DATE))'
    );
    add_constraint_if_missing(
        'CK_USER_MISSION_DISTANCE',
        'CHECK (PERSONALITY_DISTANCE IS NULL OR PERSONALITY_DISTANCE BETWEEN 0 AND 1)'
    );
    add_constraint_if_missing(
        'CK_USER_MISSION_SCORE',
        'CHECK (RECOMMENDATION_SCORE IS NULL OR RECOMMENDATION_SCORE BETWEEN 0 AND 1)'
    );
    add_constraint_if_missing(
        'CK_USER_MISSION_SLOT',
        'CHECK (DAILY_SLOT_NO IS NULL OR DAILY_SLOT_NO BETWEEN 1 AND 3)'
    );
    add_constraint_if_missing(
        'CK_USER_MISSION_STATUS_SLOT',
        'CHECK ((STATUS IN (''SELECTED'', ''COMPLETED'') AND DAILY_SLOT_NO IS NOT NULL) '
        || 'OR (STATUS IN (''GENERATED'', ''SHOWN'', ''CANCELLED'') AND DAILY_SLOT_NO IS NULL))'
    );
END;
/

DECLARE
    object_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO object_count
      FROM user_constraints
     WHERE constraint_name = 'UQ_USER_MISSION_DAILY_SLOT';

    IF object_count > 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE USER_MISSION
            DROP CONSTRAINT UQ_USER_MISSION_DAILY_SLOT';
    END IF;

    SELECT COUNT(*)
      INTO object_count
      FROM user_indexes
     WHERE index_name = 'UX_USER_MISSION_ACTIVE_SLOT';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE UNIQUE INDEX UX_USER_MISSION_ACTIVE_SLOT
                ON USER_MISSION (
                    CASE WHEN STATUS IN (''SELECTED'', ''COMPLETED'') THEN USER_ID END,
                    CASE WHEN STATUS IN (''SELECTED'', ''COMPLETED'') THEN SERVICE_DATE END,
                    CASE WHEN STATUS IN (''SELECTED'', ''COMPLETED'') THEN DAILY_SLOT_NO END
                )';
    END IF;
END;
/

DECLARE
    index_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO index_count
      FROM user_indexes
     WHERE index_name = 'IX_USER_MISSION_OFFER_BATCH';

    IF index_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE INDEX IX_USER_MISSION_OFFER_BATCH
                ON USER_MISSION (USER_ID, SERVICE_DATE, OFFER_BATCH_ID)';
    END IF;
END;
/

DECLARE
    table_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO table_count
      FROM user_tables
     WHERE table_name = 'USER_MISSION_SETTING';

    IF table_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE USER_MISSION_SETTING (
                USER_ID             NUMBER(19)                NOT NULL,
                AVAILABLE_TIME      VARCHAR2(10 CHAR)         NOT NULL,
                DAILY_MISSION_LIMIT NUMBER(1) DEFAULT 1       NOT NULL,
                CREATED_AT          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
                UPDATED_AT          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
                CONSTRAINT PK_USER_MISSION_SETTING PRIMARY KEY (USER_ID),
                CONSTRAINT FK_USER_MISSION_SETTING_USER
                    FOREIGN KEY (USER_ID)
                    REFERENCES NOVELTY_USER (USER_ID)
                    ON DELETE CASCADE,
                CONSTRAINT CK_USER_MISSION_SETTING_TIME
                    CHECK (AVAILABLE_TIME IN (''QUICK'', ''SHORT'', ''MEDIUM'', ''LONG'')),
                CONSTRAINT CK_USER_MISSION_SETTING_LIMIT
                    CHECK (DAILY_MISSION_LIMIT BETWEEN 1 AND 3)
            )';
    END IF;
END;
/

DECLARE
    table_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO table_count
      FROM user_tables
     WHERE table_name = 'USER_MISSION_CATEGORY_STAT';

    IF table_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE USER_MISSION_CATEGORY_STAT (
                USER_ID           NUMBER(19)                NOT NULL,
                CATEGORY          VARCHAR2(20 CHAR)         NOT NULL,
                COMPLETED_COUNT   NUMBER(10) DEFAULT 0      NOT NULL,
                LAST_COMPLETED_AT TIMESTAMP WITH TIME ZONE,
                UPDATED_AT        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
                CONSTRAINT PK_USER_MISSION_CATEGORY_STAT PRIMARY KEY (USER_ID, CATEGORY),
                CONSTRAINT FK_USER_MISSION_CATEGORY_USER
                    FOREIGN KEY (USER_ID)
                    REFERENCES NOVELTY_USER (USER_ID)
                    ON DELETE CASCADE,
                CONSTRAINT CK_USER_MISSION_CATEGORY
                    CHECK (CATEGORY IN (
                        ''MOVEMENT'', ''CREATIVE'', ''FOOD'', ''LEARNING'',
                        ''SOCIAL'', ''OUTDOOR'', ''ORGANIZING'', ''CULTURE''
                    )),
                CONSTRAINT CK_USER_MISSION_CATEGORY_COUNT
                    CHECK (COMPLETED_COUNT >= 0),
                CONSTRAINT CK_USER_MISSION_CATEGORY_TIME
                    CHECK (
                        (COMPLETED_COUNT = 0 AND LAST_COMPLETED_AT IS NULL)
                        OR (COMPLETED_COUNT > 0 AND LAST_COMPLETED_AT IS NOT NULL)
                    )
            )';
    END IF;
END;
/

DECLARE
    index_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO index_count
      FROM user_indexes
     WHERE index_name = 'IX_USER_MISSION_CATEGORY_COUNT';

    IF index_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE INDEX IX_USER_MISSION_CATEGORY_COUNT
                ON USER_MISSION_CATEGORY_STAT (USER_ID, COMPLETED_COUNT, CATEGORY)';
    END IF;
END;
/

DECLARE
    column_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO column_count
      FROM user_tab_columns
     WHERE table_name = 'USER_PERSONALITY_PROFILE'
       AND column_name = 'LAST_MISSION_ADAPTED_COUNT';

    IF column_count = 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE USER_PERSONALITY_PROFILE ADD (
                LAST_MISSION_ADAPTED_COUNT NUMBER(10) DEFAULT 0 NOT NULL
            )';
    END IF;
END;
/

DECLARE
    constraint_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO constraint_count
      FROM user_constraints
     WHERE constraint_name = 'CK_USER_LAST_MISSION_ADAPTED';

    IF constraint_count > 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE USER_PERSONALITY_PROFILE
            DROP CONSTRAINT CK_USER_LAST_MISSION_ADAPTED';
    END IF;

    EXECUTE IMMEDIATE '
        ALTER TABLE USER_PERSONALITY_PROFILE
        ADD CONSTRAINT CK_USER_LAST_MISSION_ADAPTED
        CHECK (
            LAST_MISSION_ADAPTED_COUNT >= 0
            AND LAST_MISSION_ADAPTED_COUNT <= COMPLETED_MISSION_COUNT
        )';
END;
/

DECLARE
    column_count NUMBER;
    PROCEDURE add_log_column_if_missing(column_name_value VARCHAR2, definition_value VARCHAR2) IS
    BEGIN
        SELECT COUNT(*)
          INTO column_count
          FROM user_tab_columns
         WHERE table_name = 'MISSION_STATUS_LOG'
           AND column_name = column_name_value;

        IF column_count = 0 THEN
            EXECUTE IMMEDIATE 'ALTER TABLE MISSION_STATUS_LOG ADD (' || definition_value || ')';
        END IF;
    END;
BEGIN
    add_log_column_if_missing('USER_MISSION_ID', 'USER_MISSION_ID NUMBER(19)');
    add_log_column_if_missing('PREVIOUS_STATUS', 'PREVIOUS_STATUS VARCHAR2(12 CHAR)');
    add_log_column_if_missing('CHANGE_REASON', 'CHANGE_REASON VARCHAR2(32 CHAR)');
END;
/

DECLARE
    constraint_count NUMBER;
    PROCEDURE add_log_constraint_if_missing(name_value VARCHAR2, definition_value VARCHAR2) IS
    BEGIN
        SELECT COUNT(*)
          INTO constraint_count
          FROM user_constraints
         WHERE constraint_name = name_value;

        IF constraint_count = 0 THEN
            EXECUTE IMMEDIATE 'ALTER TABLE MISSION_STATUS_LOG ADD CONSTRAINT '
                    || name_value || ' ' || definition_value;
        END IF;
    END;
BEGIN
    add_log_constraint_if_missing(
        'FK_MISSION_LOG_USER_MISSION',
        'FOREIGN KEY (USER_MISSION_ID) REFERENCES USER_MISSION (USER_MISSION_ID)'
    );
    add_log_constraint_if_missing(
        'CK_MISSION_LOG_PREVIOUS_STATUS',
        'CHECK (PREVIOUS_STATUS IS NULL OR PREVIOUS_STATUS IN '
        || '(''GENERATED'', ''SHOWN'', ''SELECTED'', ''CANCELLED'', ''COMPLETED''))'
    );
END;
/

DECLARE
    index_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO index_count
      FROM user_indexes
     WHERE index_name = 'IX_MISSION_LOG_USER_MISSION_ID';

    IF index_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE INDEX IX_MISSION_LOG_USER_MISSION_ID
                ON MISSION_STATUS_LOG (USER_MISSION_ID, OCCURRED_AT)';
    END IF;
END;
/

-- MISSION_V1_PHASE1_END

-- WORLD_V1_PHASE2_START

DECLARE
    column_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO column_count
      FROM user_tab_columns
     WHERE table_name = 'WORLD_OBJECT' AND column_name = 'MAX_LEVEL';
    IF column_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE WORLD_OBJECT ADD MAX_LEVEL NUMBER(3) DEFAULT 5 NOT NULL';
    END IF;
END;
/

DECLARE
    PROCEDURE drop_column_if_exists(table_name_value VARCHAR2, column_name_value VARCHAR2) IS
        column_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO column_count
          FROM user_tab_columns
         WHERE table_name = table_name_value AND column_name = column_name_value;
        IF column_count > 0 THEN
            EXECUTE IMMEDIATE 'ALTER TABLE ' || table_name_value || ' DROP COLUMN ' || column_name_value;
        END IF;
    END;
BEGIN
    drop_column_if_exists('WORLD_OBJECT_LEVEL', 'GLB_ASSET_URI');
    drop_column_if_exists('WORLD_OBJECT_LEVEL', 'ASSET_LOCATION');
    drop_column_if_exists('WORLD_OBJECT_LEVEL', 'ANIMATION_NAME');
    drop_column_if_exists('USER_WORLD_OBJECT', 'PLACEMENT_X');
    drop_column_if_exists('USER_WORLD_OBJECT', 'PLACEMENT_Y');
    drop_column_if_exists('USER_WORLD_OBJECT', 'PLACEMENT_Z');
    drop_column_if_exists('USER_WORLD_OBJECT', 'ROTATION_Y');
    drop_column_if_exists('USER_WORLD_OBJECT', 'SCALE_VALUE');
END;
/

DECLARE
    constraint_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO constraint_count FROM user_constraints
     WHERE constraint_name = 'UQ_WORLD_OBJECT_CATEGORY';
    IF constraint_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE WORLD_OBJECT ADD CONSTRAINT UQ_WORLD_OBJECT_CATEGORY UNIQUE (CATEGORY)';
    END IF;

    SELECT COUNT(*) INTO constraint_count FROM user_constraints
     WHERE constraint_name = 'CK_WORLD_OBJECT_MAX_LEVEL';
    IF constraint_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE WORLD_OBJECT ADD CONSTRAINT CK_WORLD_OBJECT_MAX_LEVEL CHECK (MAX_LEVEL = 5)';
    END IF;
END;
/

MERGE INTO WORLD_OBJECT target
USING (
    SELECT 'TRAINING_CORNER' object_code, '운동 코너' display_name, 'MOVEMENT' category FROM dual UNION ALL
    SELECT 'ART_EASEL', '창작 이젤', 'CREATIVE' FROM dual UNION ALL
    SELECT 'KITCHEN_TABLE', '요리 테이블', 'FOOD' FROM dual UNION ALL
    SELECT 'BOOKSHELF', '책장', 'LEARNING' FROM dual UNION ALL
    SELECT 'MESSAGE_BOARD', '소통 보드', 'SOCIAL' FROM dual UNION ALL
    SELECT 'INDOOR_GARDEN', '실내 정원', 'OUTDOOR' FROM dual UNION ALL
    SELECT 'STORAGE_CABINET', '수납장', 'ORGANIZING' FROM dual UNION ALL
    SELECT 'RECORD_PLAYER', '레코드 플레이어', 'CULTURE' FROM dual
) source
ON (target.OBJECT_CODE = source.object_code)
WHEN MATCHED THEN UPDATE SET
    target.DISPLAY_NAME = source.display_name,
    target.CATEGORY = source.category,
    target.MAX_LEVEL = 5,
    target.ENABLED = 'Y',
    target.UPDATED_AT = CURRENT_TIMESTAMP
WHEN NOT MATCHED THEN INSERT (
    WORLD_OBJECT_ID, OBJECT_CODE, DISPLAY_NAME, CATEGORY,
    MAX_LEVEL, ENABLED, CREATED_AT, UPDATED_AT
) VALUES (
    WORLD_OBJECT_SEQ.NEXTVAL, source.object_code, source.display_name, source.category,
    5, 'Y', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
);

MERGE INTO WORLD_OBJECT_LEVEL target
USING (
    SELECT object.WORLD_OBJECT_ID, level_source.OBJECT_LEVEL, level_source.REQUIRED_EXPERIENCE
      FROM WORLD_OBJECT object
      CROSS JOIN (
          SELECT 1 OBJECT_LEVEL, 0 REQUIRED_EXPERIENCE FROM dual UNION ALL
          SELECT 2, 50 FROM dual UNION ALL
          SELECT 3, 120 FROM dual UNION ALL
          SELECT 4, 220 FROM dual UNION ALL
          SELECT 5, 350 FROM dual
      ) level_source
     WHERE object.OBJECT_CODE IN (
         'TRAINING_CORNER', 'ART_EASEL', 'KITCHEN_TABLE', 'BOOKSHELF',
         'MESSAGE_BOARD', 'INDOOR_GARDEN', 'STORAGE_CABINET', 'RECORD_PLAYER'
     )
) source
ON (target.WORLD_OBJECT_ID = source.WORLD_OBJECT_ID
    AND target.OBJECT_LEVEL = source.OBJECT_LEVEL)
WHEN MATCHED THEN UPDATE SET
    target.REQUIRED_EXPERIENCE = source.REQUIRED_EXPERIENCE
WHEN NOT MATCHED THEN INSERT (
    WORLD_OBJECT_ID, OBJECT_LEVEL, REQUIRED_EXPERIENCE, CREATED_AT
) VALUES (
    source.WORLD_OBJECT_ID, source.OBJECT_LEVEL, source.REQUIRED_EXPERIENCE, CURRENT_TIMESTAMP
);

COMMIT;

-- WORLD_V1_PHASE2_END
