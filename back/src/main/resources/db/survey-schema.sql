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
