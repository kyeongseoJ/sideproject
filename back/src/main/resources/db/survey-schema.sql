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
     WHERE sequence_name = 'USER_MISSION_SEQ';

    IF object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE SEQUENCE USER_MISSION_SEQ
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
END;
/

DECLARE
    object_count NUMBER;
BEGIN
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
    SELECT COUNT(*) INTO object_count FROM user_constraints
     WHERE constraint_name = 'FK_USER_MISSION_USER';
    SELECT COUNT(*) INTO table_count FROM user_tables
     WHERE table_name = 'NOVELTY_USER';
    IF object_count = 0 AND table_count = 1 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE USER_MISSION ADD CONSTRAINT FK_USER_MISSION_USER
            FOREIGN KEY (USER_ID) REFERENCES NOVELTY_USER (USER_ID) ON DELETE CASCADE';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
    table_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO object_count FROM user_constraints
     WHERE constraint_name = 'FK_USER_MISSION_MISSION';
    SELECT COUNT(*) INTO table_count FROM user_tables
     WHERE table_name = 'MISSION';
    IF object_count = 0 AND table_count = 1 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE USER_MISSION ADD CONSTRAINT FK_USER_MISSION_MISSION
            FOREIGN KEY (MISSION_ID) REFERENCES MISSION (MISSION_ID)';
    END IF;
END;
/

DECLARE
    object_count NUMBER;
    table_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO object_count FROM user_constraints
     WHERE constraint_name = 'FK_USER_WORLD_OBJECT_USER';
    SELECT COUNT(*) INTO table_count FROM user_tables
     WHERE table_name = 'NOVELTY_USER';
    IF object_count = 0 AND table_count = 1 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE USER_WORLD_OBJECT ADD CONSTRAINT FK_USER_WORLD_OBJECT_USER
            FOREIGN KEY (USER_ID) REFERENCES NOVELTY_USER (USER_ID) ON DELETE CASCADE';
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
                CONSTRAINT CK_MISSION_ENABLED CHECK (ENABLED IN (''Y'', ''N'')),
                CONSTRAINT CK_MISSION_SOURCE_TYPE CHECK (SOURCE_TYPE IN (''BASE'', ''LLM''))
            )';
    END IF;
END;
/

MERGE INTO MISSION target
USING (
    SELECT '동네에서 처음 보는 골목 한 바퀴 걷기' title, '동네의 익숙하지 않은 골목을 골라 10분 동안 천천히 걸어 보세요.' description, 'OUTDOOR' category, 1 difficulty, 10 estimated_minutes, 1 indoor_outdoor, -1 social_level, 1 activity_level, 1 novelty_level FROM dual UNION ALL
    SELECT '서점에서 평소 안 보던 분야 책 펼쳐보기', '서점이나 도서관에서 평소 고르지 않던 분야의 책을 찾아 다섯 쪽 읽어 보세요.', 'LEARNING', 1, 15, 1, -1, 0, 2 FROM dual UNION ALL
    SELECT '처음 보는 재료로 간단한 간식 만들기', '사용해 본 적 없는 재료 하나를 골라 간단한 간식이나 음료를 만들어 보세요.', 'FOOD', 2, 30, -1, -1, 1, 2 FROM dual UNION ALL
    SELECT '주변 사람에게 짧은 안부 보내기', '최근 대화하지 않은 지인 한 명에게 부담 없는 한 문장 안부를 보내 보세요.', 'SOCIAL', 1, 5, 0, 1, 0, 1 FROM dual UNION ALL
    SELECT '좋아하지 않던 색으로 작은 그림 그리기', '평소 잘 쓰지 않는 색 세 가지를 골라 작은 추상 그림을 완성해 보세요.', 'CREATIVE', 1, 15, -1, -1, 0, 2 FROM dual UNION ALL
    SELECT '책상 위 물건 다섯 개 자리 바꾸기', '책상 위 물건 다섯 개를 골라 더 편리하거나 새로운 배치로 바꿔 보세요.', 'ORGANIZING', 1, 10, -1, -1, 1, 1 FROM dual UNION ALL
    SELECT '낯선 음악 한 곡 끝까지 듣기', '평소 듣지 않는 장르를 골라 한 곡을 검색하고 중간에 넘기지 말고 들어 보세요.', 'CULTURE', 1, 5, -1, -1, 0, 1 FROM dual UNION ALL
    SELECT '공원에서 나무 세 종류 관찰하기', '가까운 공원이나 길가에서 모양이 다른 나무 세 종류를 찾아 특징을 기록해 보세요.', 'OUTDOOR', 1, 20, 1, -1, 1, 1 FROM dual UNION ALL
    SELECT '계단을 이용해 짧게 몸 움직이기', '안전한 계단을 골라 자신의 속도로 5분 동안 오르내리고 호흡을 정리해 보세요.', 'MOVEMENT', 2, 10, 0, -1, 2, 1 FROM dual UNION ALL
    SELECT '직원에게 오늘의 추천 하나 묻기', '카페나 가게에서 직원에게 오늘 추천하는 메뉴나 물건 하나를 정중하게 물어보세요.', 'SOCIAL', 2, 10, 1, 1, 0, 2 FROM dual UNION ALL
    SELECT '한 번도 안 해본 정리 기준 적용하기', '서랍 하나를 색상, 사용 빈도 또는 크기 중 평소와 다른 기준으로 정리해 보세요.', 'ORGANIZING', 1, 20, -1, -1, 1, 2 FROM dual UNION ALL
    SELECT '짧은 외국어 표현 실제로 사용하기', '새로운 외국어 인사말 하나를 익힌 뒤 혼잣말이나 대화에서 한 번 사용해 보세요.', 'LEARNING', 1, 10, 0, 0, 0, 2 FROM dual
) source
ON (target.TITLE_NORMALIZED = UPPER(REPLACE(source.title, ' ', '')))
WHEN NOT MATCHED THEN
    INSERT (
        MISSION_ID, TITLE, TITLE_NORMALIZED, DESCRIPTION, CATEGORY,
        DIFFICULTY, ESTIMATED_MINUTES, INDOOR_OUTDOOR, SOCIAL_LEVEL,
        ACTIVITY_LEVEL, NOVELTY_LEVEL, ENABLED, SOURCE_TYPE, CONTENT_FINGERPRINT
    ) VALUES (
        MISSION_SEQ.NEXTVAL, source.title, UPPER(REPLACE(source.title, ' ', '')),
        source.description, source.category, source.difficulty, source.estimated_minutes,
        source.indoor_outdoor, source.social_level, source.activity_level,
        source.novelty_level, 'Y', 'BASE',
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
                NICKNAME            VARCHAR2(36 CHAR) NOT NULL,
                NICKNAME_NORMALIZED VARCHAR2(36 CHAR) NOT NULL,
                CREATED_AT          TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
                UPDATED_AT          TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
                LAST_SEEN_AT        TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
                CONSTRAINT PK_NOVELTY_USER PRIMARY KEY (USER_ID),
                CONSTRAINT UQ_NOVELTY_USER_KEY_HASH UNIQUE (USER_KEY_HASH),
                CONSTRAINT UQ_NOVELTY_USER_NICKNAME UNIQUE (NICKNAME_NORMALIZED),
                CONSTRAINT CK_NOVELTY_USER_NICKNAME_LENGTH
                    CHECK (LENGTH(NICKNAME) BETWEEN 1 AND 12)
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
