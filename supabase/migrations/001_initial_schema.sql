-- Novelty initial schema for Supabase PostgreSQL.
-- This is the operational PostgreSQL migration. The Oracle reference is archived at docs/archive/DB-oracle.sql.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SEQUENCE IF NOT EXISTS survey_response_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE IF NOT EXISTS world_object_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE IF NOT EXISTS mission_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE IF NOT EXISTS mission_llm_generation_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE IF NOT EXISTS novelty_user_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE IF NOT EXISTS nickname_banned_word_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE IF NOT EXISTS mission_status_log_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE IF NOT EXISTS user_mission_seq START WITH 1 INCREMENT BY 1;

CREATE TABLE IF NOT EXISTS novelty_user (
    user_id bigint PRIMARY KEY,
    user_key_hash varchar(64) NOT NULL UNIQUE,
    login_id_normalized varchar(20) UNIQUE,
    password_hash varchar(255),
    nickname varchar(36) NOT NULL,
    nickname_normalized varchar(36) NOT NULL UNIQUE,
    created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_novelty_user_account_pair CHECK (
        (login_id_normalized IS NULL AND password_hash IS NULL)
        OR (login_id_normalized IS NOT NULL AND password_hash IS NOT NULL)
    ),
    CONSTRAINT ck_novelty_user_login_id CHECK (
        login_id_normalized IS NULL
        OR login_id_normalized ~ '^[a-z0-9_]{4,20}$'
    ),
    CONSTRAINT ck_novelty_user_nickname_length CHECK (char_length(nickname) BETWEEN 1 AND 12)
);

CREATE TABLE IF NOT EXISTS nickname_banned_word (
    banned_word_id bigint PRIMARY KEY,
    word_normalized varchar(36) NOT NULL UNIQUE,
    active char(1) NOT NULL DEFAULT 'Y' CHECK (active IN ('Y', 'N')),
    created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS survey_response (
    survey_id bigint PRIMARY KEY,
    user_id bigint REFERENCES novelty_user(user_id),
    submission_key varchar(64),
    activity_level varchar(10) NOT NULL CHECK (activity_level IN ('INDOOR', 'MIXED', 'OUTDOOR')),
    social_activity varchar(10) NOT NULL CHECK (social_activity IN ('LOW', 'MEDIUM', 'HIGH')),
    physical_activity_level varchar(10) CHECK (physical_activity_level IN ('LOW', 'MEDIUM', 'HIGH')),
    novelty_tolerance varchar(10) NOT NULL CHECK (novelty_tolerance IN ('LOW', 'MEDIUM', 'HIGH')),
    execution_style varchar(16) CHECK (execution_style IN ('PLANNED', 'FLEXIBLE', 'SPONTANEOUS')),
    analysis_mode varchar(12) CHECK (analysis_mode IN ('INITIAL', 'REANALYSIS')),
    analysis_version varchar(24),
    energy_level varchar(10) CHECK (energy_level IN ('LOW', 'MEDIUM', 'HIGH')),
    created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_survey_user_submission UNIQUE (user_id, submission_key)
);

CREATE TABLE IF NOT EXISTS survey_interest (
    survey_id bigint NOT NULL REFERENCES survey_response(survey_id) ON DELETE CASCADE,
    interest_code varchar(20) NOT NULL,
    PRIMARY KEY (survey_id, interest_code),
    CONSTRAINT ck_survey_interest_code CHECK (interest_code IN (
        'MOVEMENT', 'CREATIVE', 'FOOD', 'LEARNING', 'SOCIAL',
        'OUTDOOR', 'ORGANIZING', 'CULTURE'
    ))
);

CREATE TABLE IF NOT EXISTS user_personality_profile (
    user_id bigint PRIMARY KEY REFERENCES novelty_user(user_id) ON DELETE CASCADE,
    personality_code varchar(32) NOT NULL CHECK (personality_code IN (
        'QUIET_FOCUSER', 'COZY_EXPLORER', 'WARM_HOST', 'FLEXIBLE_INDEPENDENT',
        'BALANCED_COORDINATOR', 'OPEN_CONNECTOR', 'SOLO_EXPLORER',
        'FREE_PIONEER', 'ACTIVE_CONNECTOR'
    )),
    activity_score smallint NOT NULL CHECK (activity_score IN (-1, 0, 1)),
    social_score smallint NOT NULL CHECK (social_score IN (-1, 0, 1)),
    novelty_score smallint NOT NULL CHECK (novelty_score IN (0, 1, 2)),
    physical_activity_score smallint NOT NULL DEFAULT 0 CHECK (physical_activity_score IN (0, 1, 2)),
    completed_mission_count integer NOT NULL DEFAULT 0 CHECK (completed_mission_count >= 0),
    last_mission_adapted_count integer NOT NULL DEFAULT 0,
    execution_style varchar(16) NOT NULL CHECK (execution_style IN ('PLANNED', 'FLEXIBLE', 'SPONTANEOUS')),
    source_survey_id bigint NOT NULL REFERENCES survey_response(survey_id),
    analysis_version varchar(24) NOT NULL,
    analyzed_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_user_last_mission_adapted CHECK (
        last_mission_adapted_count >= 0
        AND last_mission_adapted_count <= completed_mission_count
    )
);

CREATE TABLE IF NOT EXISTS user_profile_interest (
    user_id bigint NOT NULL REFERENCES novelty_user(user_id) ON DELETE CASCADE,
    interest_code varchar(20) NOT NULL,
    PRIMARY KEY (user_id, interest_code),
    CONSTRAINT ck_user_profile_interest_code CHECK (interest_code IN (
        'MOVEMENT', 'CREATIVE', 'FOOD', 'LEARNING', 'SOCIAL',
        'OUTDOOR', 'ORGANIZING', 'CULTURE'
    ))
);

CREATE TABLE IF NOT EXISTS mission (
    mission_id bigint PRIMARY KEY,
    title varchar(100) NOT NULL,
    title_normalized varchar(100) NOT NULL UNIQUE,
    description varchar(500) NOT NULL,
    category varchar(20) NOT NULL CHECK (category IN (
        'MOVEMENT', 'CREATIVE', 'FOOD', 'LEARNING', 'SOCIAL',
        'OUTDOOR', 'ORGANIZING', 'CULTURE'
    )),
    difficulty smallint NOT NULL CHECK (difficulty BETWEEN 1 AND 3),
    estimated_minutes smallint NOT NULL CHECK (estimated_minutes BETWEEN 1 AND 180),
    indoor_outdoor smallint NOT NULL CHECK (indoor_outdoor IN (-1, 0, 1)),
    social_level smallint NOT NULL CHECK (social_level IN (-1, 0, 1)),
    activity_level smallint NOT NULL CHECK (activity_level IN (0, 1, 2)),
    novelty_level smallint NOT NULL CHECK (novelty_level IN (0, 1, 2)),
    action_type varchar(24) NOT NULL CHECK (action_type IN (
        'EXPLORE', 'OBSERVE', 'CREATE', 'CONNECT', 'ORGANIZE',
        'EXERCISE', 'ASK', 'PRACTICE', 'TASTE', 'LISTEN'
    )),
    creativity_level smallint NOT NULL CHECK (creativity_level IN (0, 1, 2)),
    unpredictability_level smallint NOT NULL CHECK (unpredictability_level IN (0, 1, 2)),
    comfort_zone_distance smallint NOT NULL CHECK (comfort_zone_distance IN (0, 1, 2)),
    cost_level smallint NOT NULL CHECK (cost_level IN (0, 1, 2)),
    tags varchar(400) NOT NULL,
    enabled char(1) NOT NULL DEFAULT 'Y' CHECK (enabled IN ('Y', 'N')),
    source_type varchar(8) NOT NULL DEFAULT 'BASE' CHECK (source_type IN ('BASE', 'LLM')),
    content_fingerprint varchar(64) NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_mission_tags CHECK (tags ~ '^[A-Z0-9_가-힣]+(,[A-Z0-9_가-힣]+)*$'),
    CONSTRAINT ck_mission_tag_count CHECK ((length(tags) - length(replace(tags, ',', ''))) <= 9),
    CONSTRAINT ck_mission_tag_length CHECK (tags !~ '(^|,)[^,]{31}')
);

CREATE TABLE IF NOT EXISTS mission_llm_generation (
    generation_id bigint PRIMARY KEY,
    user_id bigint NOT NULL REFERENCES novelty_user(user_id) ON DELETE CASCADE,
    completion_milestone integer NOT NULL CHECK (completion_milestone >= 5 AND mod(completion_milestone, 5) = 0),
    status varchar(12) NOT NULL CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED')),
    mission_id bigint REFERENCES mission(mission_id),
    model_name varchar(100),
    error_code varchar(40),
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user_id, completion_milestone)
);

CREATE TABLE IF NOT EXISTS mission_status_log (
    status_log_id bigint PRIMARY KEY,
    user_id bigint NOT NULL REFERENCES novelty_user(user_id) ON DELETE CASCADE,
    mission_id bigint NOT NULL REFERENCES mission(mission_id),
    user_mission_id bigint,
    category varchar(20) NOT NULL,
    previous_status varchar(12),
    status varchar(12) NOT NULL CHECK (status IN ('GENERATED', 'SHOWN', 'SELECTED', 'CANCELLED', 'COMPLETED')),
    change_reason varchar(32),
    occurred_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_mission_log_previous_status CHECK (
        previous_status IS NULL OR previous_status IN ('GENERATED', 'SHOWN', 'SELECTED', 'CANCELLED', 'COMPLETED')
    )
);

CREATE TABLE IF NOT EXISTS user_mission (
    user_mission_id bigint PRIMARY KEY,
    user_id bigint NOT NULL REFERENCES novelty_user(user_id) ON DELETE CASCADE,
    mission_id bigint NOT NULL REFERENCES mission(mission_id),
    status varchar(12) NOT NULL CHECK (status IN ('GENERATED', 'SHOWN', 'SELECTED', 'CANCELLED', 'COMPLETED')),
    available_time varchar(10) NOT NULL CHECK (available_time IN ('QUICK', 'SHORT', 'MEDIUM', 'LONG')),
    service_date date NOT NULL,
    selected_at timestamptz,
    cancelled_at timestamptz,
    completed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    offer_batch_id varchar(64) NOT NULL,
    personality_distance numeric(8, 7) CHECK (personality_distance BETWEEN 0 AND 1),
    recommendation_score numeric(8, 7) CHECK (recommendation_score BETWEEN 0 AND 1),
    daily_slot_no smallint CHECK (daily_slot_no BETWEEN 1 AND 3),
    shown_at timestamptz,
    UNIQUE (user_id, mission_id, service_date),
    CONSTRAINT ck_user_mission_status_slot CHECK (
        (status IN ('SELECTED', 'COMPLETED') AND daily_slot_no IS NOT NULL)
        OR (status IN ('GENERATED', 'SHOWN', 'CANCELLED') AND daily_slot_no IS NULL)
    )
);

CREATE TABLE IF NOT EXISTS user_mission_setting (
    user_id bigint PRIMARY KEY REFERENCES novelty_user(user_id) ON DELETE CASCADE,
    available_time varchar(10) NOT NULL CHECK (available_time IN ('QUICK', 'SHORT', 'MEDIUM', 'LONG')),
    daily_mission_limit smallint NOT NULL DEFAULT 1 CHECK (daily_mission_limit BETWEEN 1 AND 3),
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_mission_category_stat (
    user_id bigint NOT NULL REFERENCES novelty_user(user_id) ON DELETE CASCADE,
    category varchar(20) NOT NULL,
    completed_count integer NOT NULL DEFAULT 0 CHECK (completed_count >= 0),
    last_completed_at timestamptz,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, category),
    CONSTRAINT ck_user_mission_category_time CHECK (
        (completed_count = 0 AND last_completed_at IS NULL)
        OR (completed_count > 0 AND last_completed_at IS NOT NULL)
    )
);

CREATE TABLE IF NOT EXISTS world_object (
    world_object_id bigint PRIMARY KEY,
    object_code varchar(40) NOT NULL UNIQUE,
    display_name varchar(100) NOT NULL,
    category varchar(20) NOT NULL UNIQUE CHECK (category IN (
        'MOVEMENT', 'CREATIVE', 'FOOD', 'LEARNING', 'SOCIAL',
        'OUTDOOR', 'ORGANIZING', 'CULTURE'
    )),
    max_level smallint NOT NULL DEFAULT 5 CHECK (max_level = 5),
    enabled char(1) NOT NULL DEFAULT 'Y' CHECK (enabled IN ('Y', 'N')),
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS world_object_level (
    world_object_id bigint NOT NULL REFERENCES world_object(world_object_id) ON DELETE CASCADE,
    object_level smallint NOT NULL CHECK (object_level >= 1),
    required_experience integer NOT NULL DEFAULT 0 CHECK (required_experience >= 0),
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (world_object_id, object_level)
);

CREATE TABLE IF NOT EXISTS user_world_object (
    user_id bigint NOT NULL REFERENCES novelty_user(user_id) ON DELETE CASCADE,
    world_object_id bigint NOT NULL REFERENCES world_object(world_object_id),
    current_level smallint NOT NULL,
    experience integer NOT NULL DEFAULT 0 CHECK (experience >= 0),
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, world_object_id),
    FOREIGN KEY (world_object_id, current_level)
        REFERENCES world_object_level(world_object_id, object_level)
);

ALTER TABLE mission_status_log
    DROP CONSTRAINT IF EXISTS fk_mission_log_user_mission;
ALTER TABLE mission_status_log
    ADD CONSTRAINT fk_mission_log_user_mission
    FOREIGN KEY (user_mission_id) REFERENCES user_mission(user_mission_id);

CREATE UNIQUE INDEX IF NOT EXISTS ux_user_mission_active_slot
    ON user_mission (user_id, service_date, daily_slot_no)
    WHERE status IN ('SELECTED', 'COMPLETED');

CREATE INDEX IF NOT EXISTS ix_user_mission_user_date
    ON user_mission (user_id, service_date DESC);
CREATE INDEX IF NOT EXISTS ix_user_mission_offer_batch
    ON user_mission (user_id, service_date, offer_batch_id);
CREATE INDEX IF NOT EXISTS ix_mission_log_user_occurred
    ON mission_status_log (user_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS ix_mission_log_user_mission
    ON mission_status_log (user_id, mission_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS ix_mission_log_user_mission_id
    ON mission_status_log (user_mission_id, occurred_at);
CREATE INDEX IF NOT EXISTS ix_user_mission_category_count
    ON user_mission_category_stat (user_id, completed_count, category);

INSERT INTO nickname_banned_word (banned_word_id, word_normalized, active)
VALUES
    (nextval('nickname_banned_word_seq'), '관리자', 'Y'),
    (nextval('nickname_banned_word_seq'), '운영자', 'Y'),
    (nextval('nickname_banned_word_seq'), 'ADMIN', 'Y'),
    (nextval('nickname_banned_word_seq'), 'ADMINISTRATOR', 'Y'),
    (nextval('nickname_banned_word_seq'), '씨발', 'Y'),
    (nextval('nickname_banned_word_seq'), '시발', 'Y'),
    (nextval('nickname_banned_word_seq'), '개새끼', 'Y'),
    (nextval('nickname_banned_word_seq'), '병신', 'Y'),
    (nextval('nickname_banned_word_seq'), '지랄', 'Y')
ON CONFLICT (word_normalized) DO NOTHING;

INSERT INTO world_object (world_object_id, object_code, display_name, category, max_level, enabled)
VALUES
    (nextval('world_object_seq'), 'TRAINING_CORNER', '운동 코너', 'MOVEMENT', 5, 'Y'),
    (nextval('world_object_seq'), 'ART_EASEL', '창작 이젤', 'CREATIVE', 5, 'Y'),
    (nextval('world_object_seq'), 'KITCHEN_TABLE', '요리 테이블', 'FOOD', 5, 'Y'),
    (nextval('world_object_seq'), 'BOOKSHELF', '책장', 'LEARNING', 5, 'Y'),
    (nextval('world_object_seq'), 'MESSAGE_BOARD', '소통 보드', 'SOCIAL', 5, 'Y'),
    (nextval('world_object_seq'), 'INDOOR_GARDEN', '실내 정원', 'OUTDOOR', 5, 'Y'),
    (nextval('world_object_seq'), 'STORAGE_CABINET', '수납장', 'ORGANIZING', 5, 'Y'),
    (nextval('world_object_seq'), 'RECORD_PLAYER', '레코드 플레이어', 'CULTURE', 5, 'Y')
ON CONFLICT (object_code) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    category = EXCLUDED.category,
    max_level = EXCLUDED.max_level,
    enabled = EXCLUDED.enabled,
    updated_at = CURRENT_TIMESTAMP;

INSERT INTO world_object_level (world_object_id, object_level, required_experience)
SELECT world_object_id, levels.object_level, levels.required_experience
FROM world_object
CROSS JOIN (VALUES (1, 0), (2, 50), (3, 120), (4, 220), (5, 350)) AS levels(object_level, required_experience)
ON CONFLICT (world_object_id, object_level) DO UPDATE SET
    required_experience = EXCLUDED.required_experience;

SELECT setval('world_object_seq', COALESCE((SELECT MAX(world_object_id) FROM world_object), 1), true);
SELECT setval('nickname_banned_word_seq', COALESCE((SELECT MAX(banned_word_id) FROM nickname_banned_word), 1), true);
