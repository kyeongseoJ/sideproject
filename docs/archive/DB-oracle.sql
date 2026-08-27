-- Novelty database schema for Oracle Database 21c.
--
-- This is an archived Oracle Database 21c reference for historical compatibility.
-- It is not the operational database schema and must not be used for deployment.
-- Operational schema and seed data are managed in supabase/migrations.
-- The script is retained for historical re-creation only.
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

-- Added 100 BASE missions from novelty_missions_100_oracle.sql (idempotent seed)
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '새 골목 40분 탐험하기', '새골목40분탐험하기', '집 근처에서 평소 가지 않던 방향을 정해 40분 동안 걸어보세요. 처음 보는 가게나 공간을 최소 3곳 찾아 기록합니다.', 'OUTDOOR', 1, 40, -1, -1, 1, 2, 'EXPLORE', 0, 2, 1, 0, '산책,골목,탐험,동네,발견', 'Y', 'BASE', 'ab095bb922cc2546a17ccfe723809d82ad94cb95706f4ecfe64dd41f88c526db'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'ab095bb922cc2546a17ccfe723809d82ad94cb95706f4ecfe64dd41f88c526db' OR TITLE_NORMALIZED = '새골목40분탐험하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '30분 전신 스트레칭 완주하기', '30분전신스트레칭완주하기', '전신을 목·어깨·등·허리·하체 순서로 나누어 30분 동안 천천히 스트레칭합니다. 평소 잘 하지 않는 부위도 포함합니다.', 'MOVEMENT', 1, 30, 1, -1, 1, 1, 'EXERCISE', 0, 0, 0, 0, '스트레칭,운동,전신,실내,건강', 'Y', 'BASE', 'e6350051753a9c70da14e95ee0b56b86995243abdc097890cb4d34032ad04f7f'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'e6350051753a9c70da14e95ee0b56b86995243abdc097890cb4d34032ad04f7f' OR TITLE_NORMALIZED = '30분전신스트레칭완주하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '빠르게 걷기 인터벌 해보기', '빠르게걷기인터벌해보기', '10분 보통 걷기, 15분 빠르게 걷기, 10분 천천히 걷기를 이어서 수행합니다. 중간에 멈추지 않고 속도 변화를 느껴보세요.', 'MOVEMENT', 2, 35, -1, -1, 2, 1, 'EXERCISE', 0, 0, 1, 0, '걷기,인터벌,운동,야외,체력', 'Y', 'BASE', 'd019589b39277b58abcfc30c9519f70ea93a75ed37f1a473a3d965d6a265e5a7'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'd019589b39277b58abcfc30c9519f70ea93a75ed37f1a473a3d965d6a265e5a7' OR TITLE_NORMALIZED = '빠르게걷기인터벌해보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '처음 보는 홈트 루틴 따라하기', '처음보는홈트루틴따라하기', '평소 해보지 않은 초보자용 홈트레이닝 루틴을 하나 골라 30~40분간 따라 합니다. 끝난 뒤 가장 어려웠던 동작을 기록합니다.', 'MOVEMENT', 2, 35, 1, -1, 2, 2, 'PRACTICE', 0, 1, 1, 0, '홈트,운동,새로운동작,실내,연습', 'Y', 'BASE', '0be4ee38dec4fb7454d9ba40326ea11cb48ba567845073332e5bdfecccacee59'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '0be4ee38dec4fb7454d9ba40326ea11cb48ba567845073332e5bdfecccacee59' OR TITLE_NORMALIZED = '처음보는홈트루틴따라하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '음악 한 장 들으며 산책하기', '음악한장들으며산책하기', '처음부터 끝까지 들어본 적 없는 앨범 하나를 선택해 들으면서 40~50분 산책합니다. 가장 기억에 남은 곡 하나를 고릅니다.', 'CULTURE', 1, 45, -1, -1, 1, 2, 'LISTEN', 0, 1, 1, 0, '음악,앨범,산책,감상,새로운음악', 'Y', 'BASE', '4ab012f275d0f92f7f33a4ab089761f9a936bd4ef2e21b1481f6da62009ad20f'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '4ab012f275d0f92f7f33a4ab089761f9a936bd4ef2e21b1481f6da62009ad20f' OR TITLE_NORMALIZED = '음악한장들으며산책하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '한 가지 색으로 사진 12장 찍기', '한가지색으로사진12장찍기', '색 하나를 정한 뒤 주변에서 그 색이 들어간 장면이나 사물을 찾아 사진 12장을 촬영합니다. 서로 다른 장소와 구도를 사용해보세요.', 'CREATIVE', 1, 45, 0, -1, 1, 2, 'CREATE', 2, 1, 1, 0, '사진,색상,관찰,창작,수집', 'Y', 'BASE', 'c5c3d3349ab6182635a568c5e848406fb089af5f483d978f1c71c3a83179fdc9'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'c5c3d3349ab6182635a568c5e848406fb089af5f483d978f1c71c3a83179fdc9' OR TITLE_NORMALIZED = '한가지색으로사진12장찍기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '일상 물건 정밀 스케치하기', '일상물건정밀스케치하기', '집에 있는 평범한 물건 하나를 골라 형태와 질감을 자세히 관찰하며 40분 동안 스케치합니다. 완성도보다 관찰에 집중합니다.', 'CREATIVE', 1, 40, 1, -1, 0, 1, 'OBSERVE', 2, 0, 0, 0, '그림,스케치,관찰,사물,집중', 'Y', 'BASE', '8f1c15a2e97e30994c5663ea91d047c31d9c53ebeb75dd7bfe484dee321cde37'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '8f1c15a2e97e30994c5663ea91d047c31d9c53ebeb75dd7bfe484dee321cde37' OR TITLE_NORMALIZED = '일상물건정밀스케치하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '가상 카페 메뉴판 만들기', '가상카페메뉴판만들기', '내가 카페를 연다고 상상하고 콘셉트, 메뉴 이름, 가격, 설명을 포함한 메뉴판 한 장을 45분 안에 만들어보세요.', 'CREATIVE', 1, 45, 1, -1, 0, 2, 'CREATE', 2, 1, 1, 0, '기획,카페,메뉴,디자인,창작', 'Y', 'BASE', 'ba51774d9c106c1ecfb33c6e4ae2650c400660520c01137c007be32bfed08ea5'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'ba51774d9c106c1ecfb33c6e4ae2650c400660520c01137c007be32bfed08ea5' OR TITLE_NORMALIZED = '가상카페메뉴판만들기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '짧은 이야기 한 편 완성하기', '짧은이야기한편완성하기', '무작위로 장소·사물·감정 세 가지를 정하고 모두 포함한 짧은 이야기를 40~60분 안에 처음부터 끝까지 작성합니다.', 'CREATIVE', 2, 50, 1, -1, 0, 2, 'CREATE', 2, 2, 1, 0, '글쓰기,이야기,창작,상상,문장', 'Y', 'BASE', '371b0e1a7a56397c87e818a588cb8245df1f8c8b3b41ab123e6fe926b337dc43'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '371b0e1a7a56397c87e818a588cb8245df1f8c8b3b41ab123e6fe926b337dc43' OR TITLE_NORMALIZED = '짧은이야기한편완성하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '나를 표현하는 무드보드 만들기', '나를표현하는무드보드만들기', '사진, 색, 단어, 아이콘 등을 모아 현재 나의 관심사나 분위기를 표현하는 디지털 또는 종이 무드보드를 만듭니다.', 'CREATIVE', 1, 45, 1, -1, 0, 1, 'CREATE', 2, 1, 0, 0, '무드보드,이미지,자기표현,디자인,창작', 'Y', 'BASE', 'a68e36cf8e3bb568b88b96f760ca15cef64ac1a3fcdf2d3861bb276353bccdbb'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'a68e36cf8e3bb568b88b96f760ca15cef64ac1a3fcdf2d3861bb276353bccdbb' OR TITLE_NORMALIZED = '나를표현하는무드보드만들기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '냉장고 재료로 새로운 한 끼 만들기', '냉장고재료로새로운한끼만들기', '새로운 재료를 사지 않고 현재 가지고 있는 식재료를 조합해 평소와 다른 한 끼를 만들어봅니다.', 'FOOD', 2, 50, 1, -1, 1, 2, 'TASTE', 2, 2, 1, 0, '요리,냉장고,재료,창의요리,식사', 'Y', 'BASE', 'e7774fa89869524485c5ed268048af8791e28745dc244e57e60fad1b24ce7294'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'e7774fa89869524485c5ed268048af8791e28745dc244e57e60fad1b24ce7294' OR TITLE_NORMALIZED = '냉장고재료로새로운한끼만들기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '처음 먹는 식재료 하나 시도하기', '처음먹는식재료하나시도하기', '마트나 편의점에서 먹어본 적 없는 식재료나 간식을 하나 골라 먹어보고 맛·향·식감을 세 문장으로 기록합니다.', 'FOOD', 1, 35, 0, -1, 1, 2, 'TASTE', 0, 2, 1, 1, '새로운음식,시식,마트,맛,발견', 'Y', 'BASE', 'ce9e822cb161f65c80ad723c8f6583be1eee4809be4e89938ff3d4988c85aa56'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'ce9e822cb161f65c80ad723c8f6583be1eee4809be4e89938ff3d4988c85aa56' OR TITLE_NORMALIZED = '처음먹는식재료하나시도하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '다른 나라 간단한 음식 만들기', '다른나라간단한음식만들기', '평소 자주 먹지 않는 나라의 간단한 음식 레시피를 찾아 1인분을 직접 만들어 맛봅니다.', 'FOOD', 2, 60, 1, -1, 1, 2, 'TASTE', 1, 1, 1, 1, '세계음식,요리,레시피,문화,맛', 'Y', 'BASE', '6bd5cd8ee1bed7cd7eed9f1434ba533d584f7bab4a3d6bb1f3da37967a7e4a06'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '6bd5cd8ee1bed7cd7eed9f1434ba533d584f7bab4a3d6bb1f3da37967a7e4a06' OR TITLE_NORMALIZED = '다른나라간단한음식만들기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '평범한 한 끼 새롭게 플레이팅하기', '평범한한끼새롭게플레이팅하기', '평소 먹던 메뉴를 준비한 뒤 접시 배치, 색 조합, 높낮이를 바꾸어 평소와 전혀 다른 방식으로 담아봅니다.', 'FOOD', 1, 35, 1, -1, 0, 1, 'CREATE', 2, 0, 0, 0, '플레이팅,음식,디자인,식사,창작', 'Y', 'BASE', '8765f5e1611494ea1ab0e028158b9df46947ea90643ec7f82276d5dec4970280'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '8765f5e1611494ea1ab0e028158b9df46947ea90643ec7f82276d5dec4970280' OR TITLE_NORMALIZED = '평범한한끼새롭게플레이팅하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '좋아하는 음식 레시피 개선하기', '좋아하는음식레시피개선하기', '자주 먹는 음식 하나를 정해 더 맛있게 만들 방법을 15분 조사하고 실제로 한 가지 변화를 적용해 만들어봅니다.', 'FOOD', 2, 55, 1, -1, 1, 1, 'PRACTICE', 1, 1, 1, 1, '요리,레시피,실험,개선,맛', 'Y', 'BASE', '53236cdb0c1d2f1fc7e309bb5d3787433af69c498ed81789a9ab7ab697ec98a3'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '53236cdb0c1d2f1fc7e309bb5d3787433af69c498ed81789a9ab7ab697ec98a3' OR TITLE_NORMALIZED = '좋아하는음식레시피개선하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '궁금했던 주제 5줄로 설명하기', '궁금했던주제5줄로설명하기', '평소 궁금했던 주제 하나를 정해 40분 동안 자료를 찾아보고, 처음 듣는 사람도 이해할 수 있도록 핵심을 5줄로 정리합니다.', 'LEARNING', 1, 45, 1, -1, 0, 2, 'EXPLORE', 0, 1, 1, 0, '학습,조사,정리,지식,호기심', 'Y', 'BASE', '9f651433c60a8a9134336fc64e92bd9c54563fb0c64ca9a88b50eaf55e7a4eed'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '9f651433c60a8a9134336fc64e92bd9c54563fb0c64ca9a88b50eaf55e7a4eed' OR TITLE_NORMALIZED = '궁금했던주제5줄로설명하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '새로운 앱 기능 하나 익히기', '새로운앱기능하나익히기', '평소 사용하는 앱이나 프로그램에서 써본 적 없는 기능 하나를 찾아 튜토리얼을 보고 직접 3회 이상 사용해봅니다.', 'LEARNING', 1, 35, 1, -1, 0, 1, 'PRACTICE', 0, 1, 1, 0, '앱,기능,튜토리얼,연습,디지털', 'Y', 'BASE', '58d9984ab7afbb2f52bda339bf7a39acd234b490f3e22f875b4f1d9e83739554'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '58d9984ab7afbb2f52bda339bf7a39acd234b490f3e22f875b4f1d9e83739554' OR TITLE_NORMALIZED = '새로운앱기능하나익히기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '외국어 표현 15개 직접 써보기', '외국어표현15개직접써보기', '관심 있는 외국어 표현 15개를 배우고 각 표현마다 자신의 상황에 맞는 짧은 예문을 하나씩 만들어봅니다.', 'LEARNING', 1, 45, 1, -1, 0, 1, 'PRACTICE', 1, 0, 1, 0, '외국어,표현,예문,학습,언어', 'Y', 'BASE', 'bbdcfd9684e3373fd6e425e538958e64c19239680c873ce03164a27193ee8d46'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'bbdcfd9684e3373fd6e425e538958e64c19239680c873ce03164a27193ee8d46' OR TITLE_NORMALIZED = '외국어표현15개직접써보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '낯선 개념을 한 페이지로 정리하기', '낯선개념을한페이지로정리하기', '잘 모르는 개념 하나를 골라 여러 자료를 참고하고 정의, 예시, 핵심 포인트를 한 페이지에 정리합니다.', 'LEARNING', 2, 50, 1, -1, 0, 2, 'EXPLORE', 1, 1, 1, 0, '개념,공부,정리,조사,학습', 'Y', 'BASE', 'a3ab92f58c40f0591984b4e6744f1eb0f7f6d402227aa310ca714b6c4966ccd6'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'a3ab92f58c40f0591984b4e6744f1eb0f7f6d402227aa310ca714b6c4966ccd6' OR TITLE_NORMALIZED = '낯선개념을한페이지로정리하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '관심 직무 채용공고 3개 비교하기', '관심직무채용공고3개비교하기', '관심 있는 직무의 채용공고 3개를 찾아 공통 요구역량과 서로 다른 요구사항을 표나 메모로 비교합니다.', 'LEARNING', 1, 50, 1, -1, 0, 1, 'OBSERVE', 0, 0, 1, 0, '채용공고,직무,비교,커리어,분석', 'Y', 'BASE', '93f48cdf0a0dc737ac3652616f6ed18436384ec02d71f9cad8d3416d19dcc64c'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '93f48cdf0a0dc737ac3652616f6ed18436384ec02d71f9cad8d3416d19dcc64c' OR TITLE_NORMALIZED = '관심직무채용공고3개비교하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '오랜만인 사람에게 안부 묻기', '오랜만인사람에게안부묻기', '한동안 연락하지 않았던 사람 한 명에게 먼저 연락해 근황을 묻고 최소 20분 이상 대화를 이어가봅니다.', 'SOCIAL', 2, 35, 0, 1, 0, 2, 'CONNECT', 0, 2, 2, 0, '연락,대화,안부,관계,소통', 'Y', 'BASE', 'db14747a9d9ed26b3c1ad8d144dc2fcd70f46568dc55da6071c4b519f92d7703'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'db14747a9d9ed26b3c1ad8d144dc2fcd70f46568dc55da6071c4b519f92d7703' OR TITLE_NORMALIZED = '오랜만인사람에게안부묻기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '추천 하나 받고 실제로 살펴보기', '추천하나받고실제로살펴보기', '지인에게 최근 좋았던 책, 영화, 음악 중 하나를 추천해달라고 묻고 이유를 들은 뒤 그 콘텐츠를 20분 이상 직접 살펴봅니다.', 'SOCIAL', 1, 40, 0, 1, 0, 1, 'ASK', 0, 1, 1, 0, '추천,대화,콘텐츠,관계,발견', 'Y', 'BASE', 'fd25ca6cf0275693e95080a9b2e3676bc8c47eb05fe86d0d96d3c2b136625edd'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'fd25ca6cf0275693e95080a9b2e3676bc8c47eb05fe86d0d96d3c2b136625edd' OR TITLE_NORMALIZED = '추천하나받고실제로살펴보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '고마웠던 일을 구체적으로 전하기', '고마웠던일을구체적으로전하기', '최근 또는 과거에 고마웠던 사람 한 명을 떠올려 무엇이 고마웠는지 구체적으로 정리하고 메시지나 대화로 전달합니다.', 'SOCIAL', 1, 30, 0, 1, 0, 1, 'CONNECT', 1, 1, 1, 0, '감사,메시지,관계,표현,소통', 'Y', 'BASE', '558e153edc2307c3df1f11f1829a838d7ff10769beaa97d967652ecce617dea2'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '558e153edc2307c3df1f11f1829a838d7ff10769beaa97d967652ecce617dea2' OR TITLE_NORMALIZED = '고마웠던일을구체적으로전하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '누군가와 40분 함께 걷기', '누군가와40분함께걷기', '친구나 가족 한 명과 40분 정도 함께 걸으며 최근 관심사나 기억에 남는 일을 주제로 대화합니다.', 'SOCIAL', 1, 40, -1, 1, 1, 1, 'CONNECT', 0, 1, 0, 0, '산책,대화,친구,가족,소통', 'Y', 'BASE', '85b35a011557cf6629a6e355cb27758536ba0c12e9d1b6f1213c1b3e6ba059bb'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '85b35a011557cf6629a6e355cb27758536ba0c12e9d1b6f1213c1b3e6ba059bb' OR TITLE_NORMALIZED = '누군가와40분함께걷기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '평소 안 묻던 질문 세 가지 해보기', '평소안묻던질문세가지해보기', '가까운 사람에게 평소 묻지 않았던 취향, 경험, 생각에 관한 질문 세 가지를 하고 답을 충분히 들어봅니다.', 'SOCIAL', 1, 30, 0, 1, 0, 2, 'ASK', 0, 2, 1, 0, '질문,대화,관계,호기심,소통', 'Y', 'BASE', '919d4d01ef943ea90873e165153a8fe58a0849e041275f4b109df42e5218a946'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '919d4d01ef943ea90873e165153a8fe58a0849e041275f4b109df42e5218a946' OR TITLE_NORMALIZED = '평소안묻던질문세가지해보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '동네의 새로운 장소 세 곳 찾기', '동네의새로운장소세곳찾기', '집 근처를 45분 동안 돌아다니며 처음 알게 된 공원, 가게, 골목, 건물 등 장소 세 곳을 찾아 기록합니다.', 'OUTDOOR', 1, 45, -1, -1, 1, 2, 'EXPLORE', 0, 2, 1, 0, '동네,장소,탐험,발견,야외', 'Y', 'BASE', '790359a46c342904942f1a65c28a53fc88a4aea5370ff29eb2c9cb50141d1ff5'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '790359a46c342904942f1a65c28a53fc88a4aea5370ff29eb2c9cb50141d1ff5' OR TITLE_NORMALIZED = '동네의새로운장소세곳찾기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '지도만 보고 새로운 목적지 찾아가기', '지도만보고새로운목적지찾아가기', '지도에서 가보지 않은 가까운 장소 하나를 정해 평소 경로와 다른 길로 직접 찾아갑니다.', 'OUTDOOR', 2, 50, -1, -1, 1, 2, 'EXPLORE', 0, 2, 2, 0, '지도,탐험,목적지,걷기,발견', 'Y', 'BASE', '177e1391fba4e059eb25ceb910a9b78b2006b4acb6020618be414cec009218ed'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '177e1391fba4e059eb25ceb910a9b78b2006b4acb6020618be414cec009218ed' OR TITLE_NORMALIZED = '지도만보고새로운목적지찾아가기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '공원에서 30분 관찰 기록하기', '공원에서30분관찰기록하기', '가까운 공원이나 광장에 앉아 30분 동안 소리, 움직임, 사람, 식물 등 눈에 띄는 것을 10가지 기록합니다.', 'OUTDOOR', 1, 35, -1, -1, 0, 1, 'OBSERVE', 1, 1, 1, 0, '공원,관찰,기록,야외,주변', 'Y', 'BASE', 'c30f4ee8964108d9d12f05e0cd7f8a9bc8d1e9b067489ce18cec47d73c300caa'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'c30f4ee8964108d9d12f05e0cd7f8a9bc8d1e9b067489ce18cec47d73c300caa' OR TITLE_NORMALIZED = '공원에서30분관찰기록하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '한 정거장 먼저 내려 걸어가기', '한정거장먼저내려걸어가기', '평소 대중교통을 이용하는 구간에서 한 정거장 먼저 내려 목적지까지 걸어가며 주변의 새로운 장소를 살펴봅니다.', 'OUTDOOR', 1, 30, -1, -1, 1, 1, 'EXPLORE', 0, 1, 1, 0, '걷기,교통,동네,탐색,이동', 'Y', 'BASE', 'f668129f3c6b50e169b4865a2b382cb665861d50fcda983d9ab0683632f3cd00'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'f668129f3c6b50e169b4865a2b382cb665861d50fcda983d9ab0683632f3cd00' OR TITLE_NORMALIZED = '한정거장먼저내려걸어가기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '거리 간판 다섯 개 관찰하기', '거리간판다섯개관찰하기', '30~40분 동안 거리를 걸으며 눈에 띄는 간판이나 상점 디자인 5개를 사진 또는 메모로 남기고 공통점을 찾아봅니다.', 'OUTDOOR', 1, 40, -1, -1, 1, 1, 'OBSERVE', 1, 1, 1, 0, '간판,거리,관찰,디자인,산책', 'Y', 'BASE', '619bed987ea565bbabb0d72775ea18857d5122aac98be451eb0e30be366101dc'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '619bed987ea565bbabb0d72775ea18857d5122aac98be451eb0e30be366101dc' OR TITLE_NORMALIZED = '거리간판다섯개관찰하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '책상 전체 비우고 다시 정리하기', '책상전체비우고다시정리하기', '책상 위와 서랍 한 칸을 모두 비운 뒤 필요 여부와 사용 빈도로 분류해 다시 배치합니다.', 'ORGANIZING', 1, 45, 1, -1, 1, 1, 'ORGANIZE', 1, 0, 0, 0, '정리,책상,서랍,공간,정돈', 'Y', 'BASE', '48b8f3a211a49b30910b2b1725469c6d3ce52c67cf60875fb2101dcd45d61dd4'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '48b8f3a211a49b30910b2b1725469c6d3ce52c67cf60875fb2101dcd45d61dd4' OR TITLE_NORMALIZED = '책상전체비우고다시정리하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '스마트폰 사진 300장 정리하기', '스마트폰사진300장정리하기', '최근 사진부터 확인해 중복, 실패 사진, 불필요한 캡처를 삭제하고 남길 사진은 필요한 경우 앨범으로 분류합니다.', 'ORGANIZING', 1, 45, 1, -1, 0, 0, 'ORGANIZE', 0, 0, 0, 0, '사진,스마트폰,정리,삭제,앨범', 'Y', 'BASE', '701f34d90ddac1d2bda23c5010dd7b7832de0516859ab32ecfa8c58dae3b7f62'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '701f34d90ddac1d2bda23c5010dd7b7832de0516859ab32ecfa8c58dae3b7f62' OR TITLE_NORMALIZED = '스마트폰사진300장정리하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '사용하지 않는 앱 정리하기', '사용하지않는앱정리하기', '스마트폰이나 태블릿의 설치 앱을 훑어보고 사용하지 않는 앱을 삭제하거나 폴더별로 재배치합니다.', 'ORGANIZING', 1, 30, 1, -1, 0, 0, 'ORGANIZE', 0, 0, 0, 0, '앱,스마트폰,정리,디지털,삭제', 'Y', 'BASE', '92a0d068302816da4b26194fc63828d1bf882fef05aa3c9ec5a3b628278e632f'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '92a0d068302816da4b26194fc63828d1bf882fef05aa3c9ec5a3b628278e632f' OR TITLE_NORMALIZED = '사용하지않는앱정리하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '옷장 한 구역 완전히 정리하기', '옷장한구역완전히정리하기', '옷장 한 칸이나 한 종류의 옷을 모두 꺼내 자주 입음, 보관, 정리 대상으로 나누고 다시 배치합니다.', 'ORGANIZING', 1, 50, 1, -1, 1, 0, 'ORGANIZE', 0, 0, 0, 0, '옷장,의류,정리,분류,공간', 'Y', 'BASE', 'a677f13f3044a49ea61f5250aec35f9f9903d3a76dc1b51e57b27e84a20ee4ae'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'a677f13f3044a49ea61f5250aec35f9f9903d3a76dc1b51e57b27e84a20ee4ae' OR TITLE_NORMALIZED = '옷장한구역완전히정리하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '최근 한 달 소비 내역 분류하기', '최근한달소비내역분류하기', '최근 한 달의 카드나 계좌 내역을 확인해 식비, 교통, 쇼핑 등으로 분류하고 가장 큰 지출 항목을 찾아봅니다.', 'ORGANIZING', 2, 45, 1, -1, 0, 1, 'ORGANIZE', 0, 0, 1, 0, '소비,지출,정리,분류,재정', 'Y', 'BASE', '29a48f43a4c1084a75856c49432ef1d99468aedf38d61a2f05495bc7a09eefb3'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '29a48f43a4c1084a75856c49432ef1d99468aedf38d61a2f05495bc7a09eefb3' OR TITLE_NORMALIZED = '최근한달소비내역분류하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '처음 듣는 음악 장르 탐색하기', '처음듣는음악장르탐색하기', '평소 잘 듣지 않는 음악 장르를 하나 골라 대표곡 8곡 이상을 들으며 마음에 드는 곡 3개를 저장합니다.', 'CULTURE', 1, 50, 1, -1, 0, 2, 'LISTEN', 0, 1, 1, 0, '음악,장르,감상,탐색,플레이리스트', 'Y', 'BASE', '791fc97ef7a60bdb8fc2cac8b72d95717fccd338fde1f2e7bbac7c3c8d876fc7'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '791fc97ef7a60bdb8fc2cac8b72d95717fccd338fde1f2e7bbac7c3c8d876fc7' OR TITLE_NORMALIZED = '처음듣는음악장르탐색하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '온라인 전시 하나 끝까지 둘러보기', '온라인전시하나끝까지둘러보기', '온라인 미술관이나 박물관 전시 하나를 선택해 작품 설명까지 살펴보고 기억에 남는 작품 3개를 기록합니다.', 'CULTURE', 1, 45, 1, -1, 0, 2, 'OBSERVE', 1, 1, 1, 0, '전시,미술관,박물관,온라인,감상', 'Y', 'BASE', '080e106b333ff67d78c55c402918e13e667f2a63de0d8797199ab9147a811379'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '080e106b333ff67d78c55c402918e13e667f2a63de0d8797199ab9147a811379' OR TITLE_NORMALIZED = '온라인전시하나끝까지둘러보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '낯선 예술가 작품 다섯 점 보기', '낯선예술가작품다섯점보기', '잘 모르는 예술가 한 명을 골라 대표 작품 5점 이상을 찾아보고 각 작품에서 눈에 들어오는 요소를 짧게 적습니다.', 'CULTURE', 1, 40, 1, -1, 0, 2, 'OBSERVE', 1, 1, 1, 0, '예술가,작품,미술,관찰,문화', 'Y', 'BASE', '5b35f2583d19bb630ea060a9e031c622baa16bbfea140eff2737da2189ccbbbf'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '5b35f2583d19bb630ea060a9e031c622baa16bbfea140eff2737da2189ccbbbf' OR TITLE_NORMALIZED = '낯선예술가작품다섯점보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '다른 나라 일상문화 알아보기', '다른나라일상문화알아보기', '한 나라를 정해 식사, 교통, 인사, 여가 등 일상생활 문화를 40분 동안 찾아보고 새롭게 알게 된 점 5개를 적습니다.', 'CULTURE', 1, 45, 1, -1, 0, 2, 'EXPLORE', 0, 1, 1, 0, '문화,해외,생활,조사,발견', 'Y', 'BASE', 'f9db4b56bf3d769be0d103774ea845b21cb3ef9444d785aee25e7c5b6d0b1a58'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'f9db4b56bf3d769be0d103774ea845b21cb3ef9444d785aee25e7c5b6d0b1a58' OR TITLE_NORMALIZED = '다른나라일상문화알아보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '짧은 문학작품 읽고 한 문장 남기기', '짧은문학작품읽고한문장남기기', '단편소설, 에세이, 시 묶음 중 하나를 30분 이상 읽고 가장 인상 깊었던 문장과 이유를 적습니다.', 'CULTURE', 1, 40, 1, -1, 0, 1, 'OBSERVE', 1, 0, 0, 0, '독서,문학,문장,감상,기록', 'Y', 'BASE', 'e874d415361eaeb32c3b32bc1d86812312d4319ac0ab35ccf9b1bdabd954db59'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'e874d415361eaeb32c3b32bc1d86812312d4319ac0ab35ccf9b1bdabd954db59' OR TITLE_NORMALIZED = '짧은문학작품읽고한문장남기기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '생활 동선 바꿔 40분 움직이기', '생활동선바꿔40분움직이기', '집이나 학교, 직장 주변에서 평소 반복하는 이동 경로를 피하고 새로운 길을 선택해 40분 동안 이동해봅니다.', 'MOVEMENT', 1, 40, -1, -1, 1, 2, 'EXPLORE', 0, 1, 1, 0, '이동,산책,새경로,걷기,변화', 'Y', 'BASE', '15abe2c61c01ef0e1f11f6d31c0edf1d6b3958d1c98eefe403632753d4e02ffd'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '15abe2c61c01ef0e1f11f6d31c0edf1d6b3958d1c98eefe403632753d4e02ffd' OR TITLE_NORMALIZED = '생활동선바꿔40분움직이기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '기본 동작 하나 30분 연습하기', '기본동작하나30분연습하기', '스쿼트, 런지, 균형 잡기 등 익숙하지 않은 기본 운동 동작 하나를 골라 자세를 확인하며 30분 연습합니다.', 'MOVEMENT', 2, 30, 1, -1, 2, 1, 'PRACTICE', 0, 0, 1, 0, '운동,동작,연습,자세,실내', 'Y', 'BASE', '5321f532854a2bf5cfe0c05657f189ec3b5362fefe2282846379f304e0ca29f7'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '5321f532854a2bf5cfe0c05657f189ec3b5362fefe2282846379f304e0ca29f7' OR TITLE_NORMALIZED = '기본동작하나30분연습하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '방 안 한 곳을 새롭게 꾸며보기', '방안한곳을새롭게꾸며보기', '책상 한쪽, 선반, 침대 주변 등 작은 공간 하나를 골라 기존 물건만 활용해 배치와 분위기를 바꿔봅니다.', 'CREATIVE', 1, 45, 1, -1, 1, 1, 'CREATE', 2, 1, 1, 0, '인테리어,배치,공간,창작,변화', 'Y', 'BASE', '44419a67e6b6739ba7838ef8b45c2f9008f3f2b3c4d0abcf932d7d27c885c6ae'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '44419a67e6b6739ba7838ef8b45c2f9008f3f2b3c4d0abcf932d7d27c885c6ae' OR TITLE_NORMALIZED = '방안한곳을새롭게꾸며보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '사진 한 장을 포스터로 재구성하기', '사진한장을포스터로재구성하기', '직접 찍은 사진 하나를 골라 제목, 문구, 배치를 추가해 간단한 포스터 형태로 완성합니다.', 'CREATIVE', 2, 50, 1, -1, 0, 2, 'CREATE', 2, 1, 1, 0, '사진,포스터,디자인,편집,창작', 'Y', 'BASE', 'e23826690844f510628c436517017b1e791aa4a28fceeeac372706bab8123747'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'e23826690844f510628c436517017b1e791aa4a28fceeeac372706bab8123747' OR TITLE_NORMALIZED = '사진한장을포스터로재구성하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '간식 세 가지 맛 비교하기', '간식세가지맛비교하기', '비슷한 종류의 간식이나 음료 세 가지를 준비해 맛, 향, 식감, 재구매 의향을 비교하고 순위를 정합니다.', 'FOOD', 1, 35, 1, 0, 0, 1, 'TASTE', 0, 1, 0, 1, '간식,비교,시식,맛,평가', 'Y', 'BASE', 'e4d952a34a4adac313b224acbad18ae6ada651d24e03473d2cc45d8634d7edaf'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'e4d952a34a4adac313b224acbad18ae6ada651d24e03473d2cc45d8634d7edaf' OR TITLE_NORMALIZED = '간식세가지맛비교하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '한 가지 재료 세 방식으로 먹어보기', '한가지재료세방식으로먹어보기', '달걀, 두부, 과일 등 익숙한 재료 하나를 골라 서로 다른 세 가지 방식으로 조리하거나 조합해 맛의 차이를 비교합니다.', 'FOOD', 2, 55, 1, -1, 1, 1, 'TASTE', 1, 1, 1, 1, '재료,요리,비교,실험,맛', 'Y', 'BASE', '9e6adcbf53b4131a3080e42261a9eb4869aebec75abd3cd20e58c23e4003b5c2'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '9e6adcbf53b4131a3080e42261a9eb4869aebec75abd3cd20e58c23e4003b5c2' OR TITLE_NORMALIZED = '한가지재료세방식으로먹어보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '발표 영상 하나 보고 핵심 세 가지 적기', '발표영상하나보고핵심세가지적기', '관심 분야의 강연이나 발표 영상을 30분 이상 보고 가장 중요하다고 생각한 내용 세 가지와 이유를 적습니다.', 'LEARNING', 1, 45, 1, -1, 0, 1, 'LISTEN', 0, 0, 0, 0, '강연,영상,학습,요약,지식', 'Y', 'BASE', 'f990d600cd34f6d666305c696aeab1cbb70b6fa9e942483024997afcb8e7a95d'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'f990d600cd34f6d666305c696aeab1cbb70b6fa9e942483024997afcb8e7a95d' OR TITLE_NORMALIZED = '발표영상하나보고핵심세가지적기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '누군가의 취미를 자세히 물어보기', '누군가의취미를자세히물어보기', '지인 한 명이 즐기는 취미에 대해 시작 계기, 재미있는 점, 입문 방법을 물어보고 새로운 사실을 3개 이상 알아봅니다.', 'SOCIAL', 1, 35, 0, 1, 0, 1, 'ASK', 0, 1, 1, 0, '취미,질문,대화,관계,관심', 'Y', 'BASE', '3c060781d78fb3ded8653ed67707eb33df900b02c1c6c085557b63519a6eddd5'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '3c060781d78fb3ded8653ed67707eb33df900b02c1c6c085557b63519a6eddd5' OR TITLE_NORMALIZED = '누군가의취미를자세히물어보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '내가 사는 동네의 오래된 장소 찾기', '내가사는동네의오래된장소찾기', '현재 동네에서 오래된 가게, 건물, 길 중 하나를 찾아 직접 가보고 눈에 띄는 특징을 기록합니다.', 'OUTDOOR', 1, 45, -1, -1, 1, 2, 'EXPLORE', 0, 2, 1, 0, '동네,역사,장소,탐험,관찰', 'Y', 'BASE', '484f10de73d59b71881ebda2ef288723689f6d6650dab7d95c9d6ae60d90ca49'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '484f10de73d59b71881ebda2ef288723689f6d6650dab7d95c9d6ae60d90ca49' OR TITLE_NORMALIZED = '내가사는동네의오래된장소찾기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '다운로드 폴더 완전히 정리하기', '다운로드폴더완전히정리하기', 'PC나 휴대폰의 다운로드 폴더를 파일 종류와 필요 여부에 따라 정리하고 불필요한 파일은 삭제합니다.', 'ORGANIZING', 1, 35, 1, -1, 0, 0, 'ORGANIZE', 0, 0, 0, 0, '파일,다운로드,정리,PC,디지털', 'Y', 'BASE', '40cccf4b677bc3db12b65d948d907621ee123d7bf158e67d28051e8191b9ae74'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '40cccf4b677bc3db12b65d948d907621ee123d7bf158e67d28051e8191b9ae74' OR TITLE_NORMALIZED = '다운로드폴더완전히정리하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '처음 가는 동네 한 시간 탐방하기', '처음가는동네한시간탐방하기', '대중교통이나 도보로 갈 수 있는 처음 가보는 동네를 정하고 최소 60분 동안 자유롭게 걸으며 장소 5곳 이상을 살펴봅니다.', 'OUTDOOR', 2, 75, -1, -1, 1, 2, 'EXPLORE', 0, 2, 2, 1, '동네,탐방,걷기,새로운장소,야외', 'Y', 'BASE', 'f3cfe6b6ee8db2d311389b2ef39143f612c83bcd7bc168470163d1c6b386fba0'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'f3cfe6b6ee8db2d311389b2ef39143f612c83bcd7bc168470163d1c6b386fba0' OR TITLE_NORMALIZED = '처음가는동네한시간탐방하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '공원이나 하천 코스 끝까지 걸어보기', '공원이나하천코스끝까지걸어보기', '가까운 공원, 하천, 산책로 중 하나의 코스를 정해 60분 이상 걸어봅니다. 중간에 가장 마음에 드는 지점을 하나 기록합니다.', 'MOVEMENT', 2, 75, -1, -1, 2, 1, 'EXERCISE', 0, 0, 1, 0, '산책로,걷기,운동,공원,야외', 'Y', 'BASE', 'd2c97d4c4ab1a39f4ec746e151cb5210f5a1407ae20084fc06a7e554aae543e8'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'd2c97d4c4ab1a39f4ec746e151cb5210f5a1407ae20084fc06a7e554aae543e8' OR TITLE_NORMALIZED = '공원이나하천코스끝까지걸어보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '초보 요가 한 시간 완주하기', '초보요가한시간완주하기', '초보자용 60분 요가 또는 필라테스 프로그램을 골라 처음부터 끝까지 따라 합니다. 무리되는 동작은 쉬운 자세로 대체합니다.', 'MOVEMENT', 2, 70, 1, -1, 2, 1, 'PRACTICE', 0, 0, 1, 0, '요가,필라테스,운동,실내,연습', 'Y', 'BASE', '415241d7a7ea2c69f1902ac767776f1374aff8966b49adba7f79fcd4b9ad47a5'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '415241d7a7ea2c69f1902ac767776f1374aff8966b49adba7f79fcd4b9ad47a5' OR TITLE_NORMALIZED = '초보요가한시간완주하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '새로운 스포츠 기본기 한 시간 연습하기', '새로운스포츠기본기한시간연습하기', '배드민턴, 농구 드리블, 줄넘기 등 평소 하지 않는 운동 하나를 정해 기본기 위주로 60분간 연습합니다.', 'MOVEMENT', 3, 75, 0, -1, 2, 2, 'PRACTICE', 0, 1, 2, 1, '스포츠,기본기,운동,연습,도전', 'Y', 'BASE', '9d09f9e3c034320a8c75513f9a55faae419dd3399a5da4dddca4f9452bae03d4'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '9d09f9e3c034320a8c75513f9a55faae419dd3399a5da4dddca4f9452bae03d4' OR TITLE_NORMALIZED = '새로운스포츠기본기한시간연습하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '목적지를 정해 한 시간 이상 걸어가기', '목적지를정해한시간이상걸어가기', '출발지에서 걸어서 60분 이상 걸리는 목적지를 정하고 안전한 경로를 따라 직접 걸어가봅니다.', 'MOVEMENT', 2, 70, -1, -1, 2, 2, 'EXERCISE', 0, 1, 2, 0, '걷기,목적지,운동,장거리,야외', 'Y', 'BASE', 'dc10aba20b78371f9223ca4a753f9e0464f7fd2cf0b562dc76a138901afafad7'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'dc10aba20b78371f9223ca4a753f9e0464f7fd2cf0b562dc76a138901afafad7' OR TITLE_NORMALIZED = '목적지를정해한시간이상걸어가기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '자전거로 새로운 코스 달려보기', '자전거로새로운코스달려보기', '자전거를 탈 수 있다면 익숙하지 않은 안전한 코스를 정해 60분 이상 이동하고 새로운 장소 한 곳에 들러봅니다.', 'MOVEMENT', 3, 75, -1, -1, 2, 2, 'EXPLORE', 0, 2, 2, 1, '자전거,탐험,운동,코스,야외', 'Y', 'BASE', 'a289ece8250923bb7c9e4a1a753985427c909dede0176b080e816ba47e20c11a'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'a289ece8250923bb7c9e4a1a753985427c909dede0176b080e816ba47e20c11a' OR TITLE_NORMALIZED = '자전거로새로운코스달려보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '한 작품을 처음부터 끝까지 그리기', '한작품을처음부터끝까지그리기', '주제 하나를 정해 스케치부터 세부 표현까지 60~90분 동안 작업해 그림 또는 디지털 일러스트 한 점을 완성합니다.', 'CREATIVE', 2, 75, 1, -1, 0, 2, 'CREATE', 2, 1, 1, 0, '그림,일러스트,창작,완성,집중', 'Y', 'BASE', '9c830abf994d00ed8cf3487c89d170358bf79da528d5993d4ffc832a572ac4e3'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '9c830abf994d00ed8cf3487c89d170358bf79da528d5993d4ffc832a572ac4e3' OR TITLE_NORMALIZED = '한작품을처음부터끝까지그리기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '사진으로 짧은 이야기 만들기', '사진으로짧은이야기만들기', '하나의 주제를 정해 서로 연결되는 사진 15~20장을 촬영하고 순서를 정해 하나의 짧은 사진 이야기로 구성합니다.', 'CREATIVE', 2, 90, 0, -1, 1, 2, 'CREATE', 2, 2, 2, 0, '사진,스토리,촬영,창작,구성', 'Y', 'BASE', '0d0f0fa0e19fa4d04c02fb0e3004cb094b836fb4bd07314e3371e90213b0aa64'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '0d0f0fa0e19fa4d04c02fb0e3004cb094b836fb4bd07314e3371e90213b0aa64' OR TITLE_NORMALIZED = '사진으로짧은이야기만들기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '가상 브랜드 하나 기획하기', '가상브랜드하나기획하기', '가상의 브랜드를 정하고 이름, 타깃, 핵심 콘셉트, 로고 초안, 대표 상품 하나까지 60~90분 안에 기획합니다.', 'CREATIVE', 3, 80, 1, -1, 0, 2, 'CREATE', 2, 2, 2, 0, '브랜드,기획,로고,상품,창작', 'Y', 'BASE', '1e518b7187be1d8c9116a2e2f1a723dc8a6df55ca1230c3ef88761a660f3055c'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '1e518b7187be1d8c9116a2e2f1a723dc8a6df55ca1230c3ef88761a660f3055c' OR TITLE_NORMALIZED = '가상브랜드하나기획하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '방 한 곳의 인테리어 재설계하기', '방한곳의인테리어재설계하기', '방 또는 작업 공간 하나를 대상으로 현재 문제점을 찾고 가구 배치와 분위기를 바꾼 새로운 레이아웃을 스케치합니다.', 'CREATIVE', 2, 75, 1, -1, 1, 1, 'CREATE', 2, 1, 1, 0, '인테리어,공간,배치,설계,창작', 'Y', 'BASE', '80e7bc6cacabbf207ca341e5dc5db36f476b86428cefa3b0ef951508dd123dae'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '80e7bc6cacabbf207ca341e5dc5db36f476b86428cefa3b0ef951508dd123dae' OR TITLE_NORMALIZED = '방한곳의인테리어재설계하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '1분 영상 직접 촬영하고 편집하기', '1분영상직접촬영하고편집하기', '주제를 하나 정해 필요한 장면을 직접 촬영하고 자막이나 음악을 추가해 약 1분 길이의 짧은 영상을 완성합니다.', 'CREATIVE', 3, 90, 0, -1, 1, 2, 'CREATE', 2, 2, 2, 0, '영상,촬영,편집,콘텐츠,창작', 'Y', 'BASE', 'd04b74543ce75e2b653662159fb46bda2464b6ad1e338dfb7571d12dbf2fcd63'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'd04b74543ce75e2b653662159fb46bda2464b6ad1e338dfb7571d12dbf2fcd63' OR TITLE_NORMALIZED = '1분영상직접촬영하고편집하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '좋아하는 작품의 새 포스터 만들기', '좋아하는작품의새포스터만들기', '좋아하는 영화, 게임, 책 중 하나를 골라 기존 포스터를 그대로 따라 하지 않고 새로운 콘셉트의 포스터를 제작합니다.', 'CREATIVE', 2, 75, 1, -1, 0, 2, 'CREATE', 2, 1, 1, 0, '포스터,디자인,콘텐츠,재해석,창작', 'Y', 'BASE', '644226967e03ad885727f41215d9ddb316d3d62f609917a864206480dfd85396'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '644226967e03ad885727f41215d9ddb316d3d62f609917a864206480dfd85396' OR TITLE_NORMALIZED = '좋아하는작품의새포스터만들기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '처음 만드는 요리 한 접시 완성하기', '처음만드는요리한접시완성하기', '한 번도 만들어보지 않은 요리를 골라 레시피 확인, 재료 준비, 조리, 정리까지 직접 수행합니다.', 'FOOD', 2, 90, 1, -1, 1, 2, 'TASTE', 1, 1, 1, 1, '요리,새로운메뉴,레시피,식사,도전', 'Y', 'BASE', '1e47bf5ba5dd5c336d85f4f81a34b2b267530c75018448bc108fb0840ac8a012'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '1e47bf5ba5dd5c336d85f4f81a34b2b267530c75018448bc108fb0840ac8a012' OR TITLE_NORMALIZED = '처음만드는요리한접시완성하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '한 나라의 한 끼 직접 만들어보기', '한나라의한끼직접만들어보기', '관심 있는 나라 하나를 정해 그 나라의 대표적인 가정식이나 한 끼 메뉴를 찾아 직접 만들어봅니다.', 'FOOD', 3, 100, 1, -1, 1, 2, 'TASTE', 1, 1, 2, 2, '세계음식,요리,문화,레시피,식사', 'Y', 'BASE', '9ad4a7498f08bc7fe2b6d3e6c41fa4530656fd1f3ecbd9420c0999a65dc1b9b5'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '9ad4a7498f08bc7fe2b6d3e6c41fa4530656fd1f3ecbd9420c0999a65dc1b9b5' OR TITLE_NORMALIZED = '한나라의한끼직접만들어보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '직접 장을 보고 새로운 메뉴 만들기', '직접장을보고새로운메뉴만들기', '먹어본 적 없는 재료 하나를 포함해 필요한 재료를 직접 고르고 장을 본 뒤 새로운 한 끼를 만들어봅니다.', 'FOOD', 2, 120, 0, -1, 1, 2, 'TASTE', 1, 2, 2, 2, '장보기,요리,새로운재료,식사,도전', 'Y', 'BASE', '2100aea81e9a755aff4e19d5d3c53d32d1d1c72b45a147fa88f0f146ac0af685'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '2100aea81e9a755aff4e19d5d3c53d32d1d1c72b45a147fa88f0f146ac0af685' OR TITLE_NORMALIZED = '직접장을보고새로운메뉴만들기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '레시피 두 개 비교해 내 방식으로 요리하기', '레시피두개비교해내방식으로요리하기', '같은 음식의 서로 다른 레시피 두 개를 비교한 뒤 장점을 조합해 자신만의 방식으로 한 번 만들어봅니다.', 'FOOD', 3, 100, 1, -1, 1, 2, 'CREATE', 2, 2, 2, 1, '레시피,비교,요리,실험,창작', 'Y', 'BASE', '11271ba45750d5de92c8fad76e0e3a18578c0642208094a49e2a0f8260db0779'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '11271ba45750d5de92c8fad76e0e3a18578c0642208094a49e2a0f8260db0779' OR TITLE_NORMALIZED = '레시피두개비교해내방식으로요리하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '한 끼 도시락 세트 구성하기', '한끼도시락세트구성하기', '메인, 곁들임, 간단한 디저트 또는 과일을 포함한 한 끼 도시락을 직접 계획하고 준비합니다.', 'FOOD', 2, 90, 1, -1, 1, 1, 'CREATE', 1, 1, 1, 1, '도시락,요리,식사,구성,준비', 'Y', 'BASE', '2b292f0c310b771386a05a286c98cc075645c65bdece548575c482b3698ed3c1'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '2b292f0c310b771386a05a286c98cc075645c65bdece548575c482b3698ed3c1' OR TITLE_NORMALIZED = '한끼도시락세트구성하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '시장 한 바퀴 돌며 새로운 음식 찾기', '시장한바퀴돌며새로운음식찾기', '전통시장이나 큰 식료품점을 60분 이상 둘러보며 처음 보는 음식이나 재료를 5개 이상 찾아보고 하나를 선택해 맛봅니다.', 'FOOD', 2, 75, -1, -1, 1, 2, 'TASTE', 0, 2, 2, 1, '시장,음식,재료,탐험,시식', 'Y', 'BASE', 'c9b6368819a9f603f65a53ba24f0901bdd238bb3ac7158337b2611b2b9eb58a6'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'c9b6368819a9f603f65a53ba24f0901bdd238bb3ac7158337b2611b2b9eb58a6' OR TITLE_NORMALIZED = '시장한바퀴돌며새로운음식찾기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '온라인 강의 한 시간 집중 수강하기', '온라인강의한시간집중수강하기', '관심 있는 주제의 온라인 강의를 최소 60분 수강하고 중요하다고 생각한 내용을 5개 이상 정리합니다.', 'LEARNING', 2, 70, 1, -1, 0, 1, 'LISTEN', 0, 0, 1, 0, '온라인강의,학습,집중,정리,지식', 'Y', 'BASE', 'e6a824354eb665d2b439c24695dfc443f4d084367f327f9a100ee5591c455679'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'e6a824354eb665d2b439c24695dfc443f4d084367f327f9a100ee5591c455679' OR TITLE_NORMALIZED = '온라인강의한시간집중수강하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '자료 세 개로 주제 하나 조사하기', '자료세개로주제하나조사하기', '알고 싶었던 주제 하나를 정해 서로 다른 자료 3개 이상을 읽고 공통점, 차이점, 새롭게 알게 된 점을 정리합니다.', 'LEARNING', 2, 75, 1, -1, 0, 2, 'EXPLORE', 1, 1, 1, 0, '조사,자료,비교,학습,정리', 'Y', 'BASE', 'cce0597467fffb7185d5f1f75a27d0630c39a14225a59dcd7ba79d4afe535df7'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'cce0597467fffb7185d5f1f75a27d0630c39a14225a59dcd7ba79d4afe535df7' OR TITLE_NORMALIZED = '자료세개로주제하나조사하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '새로운 프로그램 튜토리얼 완료하기', '새로운프로그램튜토리얼완료하기', '써본 적 없는 프로그램이나 도구 하나를 설치하거나 실행해 공식 또는 신뢰할 수 있는 초급 튜토리얼 하나를 끝까지 완료합니다.', 'LEARNING', 3, 90, 1, -1, 0, 2, 'PRACTICE', 1, 1, 2, 0, '프로그램,튜토리얼,도구,학습,연습', 'Y', 'BASE', '85af8157c07e539f857198202d6272c6852f9f98afbb9fa61986713608138990'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '85af8157c07e539f857198202d6272c6852f9f98afbb9fa61986713608138990' OR TITLE_NORMALIZED = '새로운프로그램튜토리얼완료하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '외국어 영상 한 편 표현 정리하기', '외국어영상한편표현정리하기', '외국어 영상이나 에피소드 하나를 보고 처음 알게 된 표현 20개를 적은 뒤 그중 10개로 직접 예문을 만들어봅니다.', 'LEARNING', 2, 90, 1, -1, 0, 2, 'LISTEN', 1, 1, 1, 0, '외국어,영상,표현,언어,학습', 'Y', 'BASE', 'af7085c7b7bfed6fe5d31befc38843ccf5b6fd12614e9d05a35a874e06e2f928'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'af7085c7b7bfed6fe5d31befc38843ccf5b6fd12614e9d05a35a874e06e2f928' OR TITLE_NORMALIZED = '외국어영상한편표현정리하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '채용공고 다섯 개 비교 분석하기', '채용공고다섯개비교분석하기', '관심 직무의 실제 채용공고 5개를 모아 공통 역량, 우대사항, 사용하는 도구, 경험 요구사항을 표로 비교합니다.', 'LEARNING', 2, 75, 1, -1, 0, 1, 'OBSERVE', 0, 0, 1, 0, '채용,직무,분석,커리어,비교', 'Y', 'BASE', 'e4ad64595172f034746250b2c23c7808a0c33fc57c7e1effaa1de0b17a1a0a31'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'e4ad64595172f034746250b2c23c7808a0c33fc57c7e1effaa1de0b17a1a0a31' OR TITLE_NORMALIZED = '채용공고다섯개비교분석하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '책 한 시간 읽고 생각 정리하기', '책한시간읽고생각정리하기', '읽고 싶었던 책을 최소 60분 집중해서 읽고 기억에 남은 내용과 자신의 생각을 각각 세 가지 이상 적습니다.', 'LEARNING', 1, 75, 1, -1, 0, 1, 'OBSERVE', 1, 0, 0, 0, '독서,책,생각,기록,학습', 'Y', 'BASE', '8f8222d2afae8060d5206b57291d0cc8246a469dd74ce9e376abdb2cdf989423'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '8f8222d2afae8060d5206b57291d0cc8246a469dd74ce9e376abdb2cdf989423' OR TITLE_NORMALIZED = '책한시간읽고생각정리하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '친구와 새로운 장소에서 한 시간 보내기', '친구와새로운장소에서한시간보내기', '친구나 가족과 둘 다 가본 적 없는 가까운 장소 하나를 정해 함께 방문하고 최소 60분 머물러봅니다.', 'SOCIAL', 2, 90, 0, 1, 1, 2, 'CONNECT', 0, 2, 2, 1, '친구,가족,장소,외출,소통', 'Y', 'BASE', '751c2d364a04007587540680686d6959d032d4be58b58a997b4a38589889bf80'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '751c2d364a04007587540680686d6959d032d4be58b58a997b4a38589889bf80' OR TITLE_NORMALIZED = '친구와새로운장소에서한시간보내기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '오랜만인 사람과 만나 이야기하기', '오랜만인사람과만나이야기하기', '한동안 만나지 못한 지인과 직접 만나거나 긴 통화를 하며 최소 60분 동안 서로의 최근 생활과 관심사를 이야기합니다.', 'SOCIAL', 2, 75, 0, 1, 0, 2, 'CONNECT', 0, 2, 2, 1, '만남,대화,지인,관계,소통', 'Y', 'BASE', '165feeccd010f0029a0b87ce254a78cb3ce8c83e015b82f0223ff5348f6c030f'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '165feeccd010f0029a0b87ce254a78cb3ce8c83e015b82f0223ff5348f6c030f' OR TITLE_NORMALIZED = '오랜만인사람과만나이야기하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '서로의 취미 하나 같이 해보기', '서로의취미하나같이해보기', '친구나 가족이 즐기는 취미 중 내가 잘 모르는 활동 하나를 배우고 최소 60분 동안 함께 직접 해봅니다.', 'SOCIAL', 3, 75, 0, 1, 1, 2, 'PRACTICE', 1, 2, 2, 1, '취미,함께하기,배우기,관계,도전', 'Y', 'BASE', '137ff2ee61c55ca3b9ca5424bec7e0e3eaa634d1cc86cdff713a978f50169500'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '137ff2ee61c55ca3b9ca5424bec7e0e3eaa634d1cc86cdff713a978f50169500' OR TITLE_NORMALIZED = '서로의취미하나같이해보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '보드게임 한 판 제대로 해보기', '보드게임한판제대로해보기', '친구나 가족과 평소 하지 않던 보드게임이나 카드게임 하나를 골라 규칙을 배우고 한 게임 이상 완료합니다.', 'SOCIAL', 2, 75, 1, 1, 0, 2, 'PRACTICE', 0, 2, 1, 1, '보드게임,게임,친구,규칙,소통', 'Y', 'BASE', 'b44fd41d407de92d48282e30f2755234030b1eb6f35c7a754073ccb2f492f8db'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'b44fd41d407de92d48282e30f2755234030b1eb6f35c7a754073ccb2f492f8db' OR TITLE_NORMALIZED = '보드게임한판제대로해보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '서로 추천한 장소 한 곳 방문하기', '서로추천한장소한곳방문하기', '지인과 서로 가보고 싶은 장소를 하나씩 제안하고 그중 한 곳을 골라 함께 방문해 최소 60분을 보내봅니다.', 'SOCIAL', 2, 90, -1, 1, 1, 2, 'CONNECT', 0, 2, 2, 1, '추천,장소,외출,친구,탐험', 'Y', 'BASE', '8fed803f2447a02978e3f44a0fc6a439b35e8d4e5541b8944e76386a3710b446'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '8fed803f2447a02978e3f44a0fc6a439b35e8d4e5541b8944e76386a3710b446' OR TITLE_NORMALIZED = '서로추천한장소한곳방문하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '지도에서 고른 세 장소 이어서 방문하기', '지도에서고른세장소이어서방문하기', '가보지 않은 지역에서 서로 가까운 장소 세 곳을 지도에서 정하고 직접 이동하며 모두 방문합니다.', 'OUTDOOR', 3, 120, -1, -1, 2, 2, 'EXPLORE', 0, 2, 2, 1, '지도,장소,탐험,이동,야외', 'Y', 'BASE', '4e0fc89d29eed25cd874e101b3de14a80382651460daf2482ccdd9dcceff956e'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '4e0fc89d29eed25cd874e101b3de14a80382651460daf2482ccdd9dcceff956e' OR TITLE_NORMALIZED = '지도에서고른세장소이어서방문하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '전통시장 한 시간 천천히 둘러보기', '전통시장한시간천천히둘러보기', '가까운 전통시장이나 재래시장을 최소 60분 둘러보며 처음 보는 가게와 상품을 관찰하고 한 곳에 들어가봅니다.', 'OUTDOOR', 2, 75, -1, -1, 1, 2, 'EXPLORE', 0, 2, 2, 1, '시장,탐험,가게,지역,야외', 'Y', 'BASE', 'c7b988b0fb1095137a6d7ff682e5013847c056f1d20140bdc2814f45b3142ed6'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'c7b988b0fb1095137a6d7ff682e5013847c056f1d20140bdc2814f45b3142ed6' OR TITLE_NORMALIZED = '전통시장한시간천천히둘러보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '사진 주제 하나로 동네 한 바퀴 돌기', '사진주제하나로동네한바퀴돌기', '빛, 간판, 나무, 빨간색 등 사진 주제 하나를 정해 60분 이상 걸으며 서로 다른 사진 20장을 촬영합니다.', 'OUTDOOR', 2, 70, -1, -1, 1, 2, 'OBSERVE', 2, 1, 1, 0, '사진,산책,주제,관찰,동네', 'Y', 'BASE', 'c08cdb9ed1435dfa1b64aaa09a380a69b80021ff8266d24b97e826352407ccb6'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'c08cdb9ed1435dfa1b64aaa09a380a69b80021ff8266d24b97e826352407ccb6' OR TITLE_NORMALIZED = '사진주제하나로동네한바퀴돌기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '대중교통으로 처음 가는 지역 내려보기', '대중교통으로처음가는지역내려보기', '익숙하지 않은 지역을 하나 정해 대중교통으로 이동한 뒤 60분 이상 걸어보며 마음에 드는 장소를 찾아봅니다.', 'OUTDOOR', 2, 90, -1, -1, 1, 2, 'EXPLORE', 0, 2, 2, 2, '대중교통,지역,탐험,산책,새로운장소', 'Y', 'BASE', 'd08dd216d4060577c44c49f02339279ac53ee3dbfb3997814135a0feee0cd80c'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'd08dd216d4060577c44c49f02339279ac53ee3dbfb3997814135a0feee0cd80c' OR TITLE_NORMALIZED = '대중교통으로처음가는지역내려보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '도시의 오래된 장소 세 곳 찾아보기', '도시의오래된장소세곳찾아보기', '지역의 오래된 건물, 시장, 거리 등을 미리 세 곳 정한 뒤 직접 이동하며 외관과 주변 분위기를 관찰합니다.', 'OUTDOOR', 2, 120, -1, -1, 2, 2, 'EXPLORE', 0, 2, 2, 1, '도시,역사,건물,탐험,관찰', 'Y', 'BASE', '29f13dcb31e9be981983c4dc8dedd9efd89f05e85b611d465e2cefe903f374b2'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '29f13dcb31e9be981983c4dc8dedd9efd89f05e85b611d465e2cefe903f374b2' OR TITLE_NORMALIZED = '도시의오래된장소세곳찾아보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '야외에서 계절 변화 15가지 찾기', '야외에서계절변화15가지찾기', '공원이나 산책로를 60분 이상 걸으며 날씨, 식물, 빛, 사람들의 옷차림 등 계절을 느낄 수 있는 변화를 15가지 찾아봅니다.', 'OUTDOOR', 1, 65, -1, -1, 1, 1, 'OBSERVE', 1, 1, 1, 0, '계절,관찰,공원,산책,자연', 'Y', 'BASE', '5b979bcf25a1100fc4f578cba798410c0a76ffc82eb119a280fc108851690be2'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '5b979bcf25a1100fc4f578cba798410c0a76ffc82eb119a280fc108851690be2' OR TITLE_NORMALIZED = '야외에서계절변화15가지찾기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '옷장 전체 정리하고 분류하기', '옷장전체정리하고분류하기', '옷장 안의 옷을 모두 확인해 자주 입는 옷, 보관할 옷, 처분 후보로 분류하고 종류별로 다시 정리합니다.', 'ORGANIZING', 2, 90, 1, -1, 1, 0, 'ORGANIZE', 0, 0, 0, 0, '옷장,의류,정리,분류,공간', 'Y', 'BASE', 'd63d6957acb2a8fe52873c3d37f4f1aa66c7f97cf6538697608c50187ca006d7'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'd63d6957acb2a8fe52873c3d37f4f1aa66c7f97cf6538697608c50187ca006d7' OR TITLE_NORMALIZED = '옷장전체정리하고분류하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '방 한 구역 완전히 다시 구성하기', '방한구역완전히다시구성하기', '선반, 책상, 화장대 등 한 공간의 물건을 모두 꺼내 사용 빈도와 목적을 기준으로 새롭게 배치합니다.', 'ORGANIZING', 2, 75, 1, -1, 1, 1, 'ORGANIZE', 1, 1, 1, 0, '공간,정리,배치,물건,재구성', 'Y', 'BASE', '38edd114c2ff948f745ac5259f7a361aba6c9c65c44abbcc47e4e8b0e2856117'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '38edd114c2ff948f745ac5259f7a361aba6c9c65c44abbcc47e4e8b0e2856117' OR TITLE_NORMALIZED = '방한구역완전히다시구성하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, 'PC 파일 구조 처음부터 정리하기', 'pc파일구조처음부터정리하기', '문서, 이미지, 다운로드, 프로젝트 파일을 살펴보고 폴더 구조를 새로 정의한 뒤 최소 60분 동안 파일을 이동·삭제·분류합니다.', 'ORGANIZING', 2, 75, 1, -1, 0, 0, 'ORGANIZE', 0, 0, 0, 0, 'PC,파일,폴더,정리,디지털', 'Y', 'BASE', '4ca739e7da5266bdaeaafce05905b27feb26e96f57ae851b8e5e79f396a88d48'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '4ca739e7da5266bdaeaafce05905b27feb26e96f57ae851b8e5e79f396a88d48' OR TITLE_NORMALIZED = 'pc파일구조처음부터정리하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '스마트폰 전체 디지털 정리하기', '스마트폰전체디지털정리하기', '사진, 다운로드 파일, 사용하지 않는 앱, 메모 등을 한 번에 점검하고 삭제와 분류를 진행합니다.', 'ORGANIZING', 2, 75, 1, -1, 0, 0, 'ORGANIZE', 0, 0, 0, 0, '스마트폰,사진,앱,정리,디지털', 'Y', 'BASE', '578706c8dba9db1071e1bd1939601fe9237e4883ee1829a9abca38899cfd3899'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '578706c8dba9db1071e1bd1939601fe9237e4883ee1829a9abca38899cfd3899' OR TITLE_NORMALIZED = '스마트폰전체디지털정리하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '한 달 일정과 할 일 다시 설계하기', '한달일정과할일다시설계하기', '앞으로 한 달의 일정과 해야 할 일을 모두 모아 중요도와 예상 시간을 기준으로 다시 배치하고 주 단위 계획을 만듭니다.', 'ORGANIZING', 2, 70, 1, -1, 0, 1, 'ORGANIZE', 1, 0, 1, 0, '일정,계획,할일,정리,시간관리', 'Y', 'BASE', '9f4b94f48c75fe4b09ea571d3c0cb0a757bc9f117ab739406f21fce3393e23d9'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '9f4b94f48c75fe4b09ea571d3c0cb0a757bc9f117ab739406f21fce3393e23d9' OR TITLE_NORMALIZED = '한달일정과할일다시설계하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '처분할 물건 열 개 실제로 분리하기', '처분할물건열개실제로분리하기', '집 안을 둘러보며 사용하지 않는 물건을 최소 10개 골라 판매, 기부, 재활용, 폐기 대상으로 실제 분리해둡니다.', 'ORGANIZING', 2, 80, 1, -1, 1, 1, 'ORGANIZE', 0, 1, 1, 0, '물건,정리,처분,미니멀,공간', 'Y', 'BASE', 'baf4d635551dae8f87e8329ce6969e222e6dc15ebd4e328649a28391667382d1'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'baf4d635551dae8f87e8329ce6969e222e6dc15ebd4e328649a28391667382d1' OR TITLE_NORMALIZED = '처분할물건열개실제로분리하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '영화 한 편 집중해서 끝까지 보기', '영화한편집중해서끝까지보기', '평소 선택하지 않던 장르나 국가의 영화 한 편을 골라 다른 일을 하지 않고 처음부터 끝까지 감상합니다.', 'CULTURE', 1, 120, 1, -1, 0, 2, 'OBSERVE', 0, 1, 1, 1, '영화,감상,문화,새로운장르,집중', 'Y', 'BASE', '9a0510c4aaa487f0c31ec690957d4d4ef84822388afd2d3c9fb91010f79e9ff2'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '9a0510c4aaa487f0c31ec690957d4d4ef84822388afd2d3c9fb91010f79e9ff2' OR TITLE_NORMALIZED = '영화한편집중해서끝까지보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '미술관이나 전시 공간 방문하기', '미술관이나전시공간방문하기', '가까운 미술관, 박물관, 갤러리 또는 전시 공간을 하나 정해 직접 방문하고 최소 60분 동안 관람합니다.', 'CULTURE', 2, 120, 0, -1, 1, 2, 'OBSERVE', 1, 1, 2, 2, '전시,미술관,박물관,문화,관람', 'Y', 'BASE', 'e4eaecbbfb1f1398a56939f30c23c3b3a26b1523d9b1130455131d41d0b7cfca'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'e4eaecbbfb1f1398a56939f30c23c3b3a26b1523d9b1130455131d41d0b7cfca' OR TITLE_NORMALIZED = '미술관이나전시공간방문하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '서점에서 낯선 분야 책 탐색하기', '서점에서낯선분야책탐색하기', '서점이나 도서관을 방문해 평소 읽지 않는 분야의 책을 최소 10권 살펴보고 가장 궁금한 책 3권을 골라봅니다.', 'CULTURE', 1, 75, 0, -1, 1, 2, 'EXPLORE', 0, 2, 1, 0, '서점,도서관,책,탐색,문화', 'Y', 'BASE', '380c575fed4af874ae2eb55cd7c153192ee6a6af675603d5ff39d58c5f54c68f'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '380c575fed4af874ae2eb55cd7c153192ee6a6af675603d5ff39d58c5f54c68f' OR TITLE_NORMALIZED = '서점에서낯선분야책탐색하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '새로운 음악 장르 한 시간 깊게 듣기', '새로운음악장르한시간깊게듣기', '낯선 음악 장르 하나를 골라 대표 아티스트와 앨범을 찾아 최소 60분 듣고 마음에 드는 곡으로 짧은 플레이리스트를 만듭니다.', 'CULTURE', 1, 70, 1, -1, 0, 2, 'LISTEN', 1, 1, 1, 0, '음악,장르,아티스트,앨범,플레이리스트', 'Y', 'BASE', '1481cc8d52efcf4bbaf6c2005a4070b547f7d9f3d603a1c03627d7ca56a68be4'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '1481cc8d52efcf4bbaf6c2005a4070b547f7d9f3d603a1c03627d7ca56a68be4' OR TITLE_NORMALIZED = '새로운음악장르한시간깊게듣기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '외국 다큐멘터리 한 편 보고 더 찾아보기', '외국다큐멘터리한편보고더찾아보기', '다른 나라의 사회나 문화를 다룬 다큐멘터리를 한 편 보고 궁금해진 내용 하나를 추가로 20분 이상 조사합니다.', 'CULTURE', 2, 110, 1, -1, 0, 2, 'OBSERVE', 0, 1, 1, 0, '다큐멘터리,해외,문화,조사,영상', 'Y', 'BASE', 'a031d466537088f6b05bccf7eda41d35bb0892d7c55c19dd4d4066851f2759b0'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'a031d466537088f6b05bccf7eda41d35bb0892d7c55c19dd4d4066851f2759b0' OR TITLE_NORMALIZED = '외국다큐멘터리한편보고더찾아보기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '지역 역사 장소 직접 방문하기', '지역역사장소직접방문하기', '현재 사는 지역이나 가까운 지역의 역사적 장소 하나를 찾아 배경을 간단히 조사한 뒤 직접 방문해 둘러봅니다.', 'CULTURE', 2, 100, -1, -1, 1, 2, 'EXPLORE', 0, 2, 2, 1, '역사,지역,장소,문화,탐방', 'Y', 'BASE', 'a75cec9b9769974fbf1fcf2d5a9d60b9433b988161becb2e733975975e099ed1'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'a75cec9b9769974fbf1fcf2d5a9d60b9433b988161becb2e733975975e099ed1' OR TITLE_NORMALIZED = '지역역사장소직접방문하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '새로운 예술 분야 한 시간 탐색하기', '새로운예술분야한시간탐색하기', '도예, 타이포그래피, 건축, 사진, 무용 등 평소 관심이 적었던 예술 분야를 정해 작품과 작가를 최소 60분 탐색합니다.', 'CULTURE', 1, 65, 1, -1, 0, 2, 'EXPLORE', 1, 1, 1, 0, '예술,작가,작품,탐색,문화', 'Y', 'BASE', '0403e80bdcbf179f9684ef94e79fd0d0d757664f6926663de4a31d11f5945b39'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '0403e80bdcbf179f9684ef94e79fd0d0d757664f6926663de4a31d11f5945b39' OR TITLE_NORMALIZED = '새로운예술분야한시간탐색하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '문화 활동 하나 직접 체험하기', '문화활동하나직접체험하기', '전시, 공연, 공방, 독립서점 프로그램 등 평소 하지 않던 문화 활동 하나를 선택해 직접 참여하거나 방문합니다.', 'CULTURE', 3, 150, 0, 0, 1, 2, 'EXPLORE', 1, 2, 2, 2, '문화활동,체험,외출,도전,경험', 'Y', 'BASE', 'd613ed2badec8e1d75c7fb12fad7e57ca7669f014d86845d3ab0da29a96e0fe4'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = 'd613ed2badec8e1d75c7fb12fad7e57ca7669f014d86845d3ab0da29a96e0fe4' OR TITLE_NORMALIZED = '문화활동하나직접체험하기');
INSERT INTO MISSION (MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY, DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL, ACTIVITY_LEVEL, NOVELTY_LEVEL, ACTION_TYPE, CREATIVITY_LEVEL, UNPREDICTABILITY_LEVEL, COMFORT_ZONE_DISTANCE, COST_LEVEL, TAGS, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT)
SELECT MISSION_SEQ.NEXTVAL, '나만의 작은 잡지 두 페이지 만들기', '나만의작은잡지두페이지만들기', '관심 주제 하나를 골라 제목, 짧은 글, 이미지, 레이아웃을 구성해 두 페이지 분량의 미니 매거진을 완성합니다.', 'CREATIVE', 3, 90, 1, -1, 0, 2, 'CREATE', 2, 2, 2, 0, '잡지,편집,디자인,글쓰기,창작', 'Y', 'BASE', '766e08dfd2cc26c6b907cb3193766d89e8d4611aa86c7a8624fac0cc65ec96c4'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM MISSION WHERE CONTENT_FINGERPRINT = '766e08dfd2cc26c6b907cb3193766d89e8d4611aa86c7a8624fac0cc65ec96c4' OR TITLE_NORMALIZED = '나만의작은잡지두페이지만들기');

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
