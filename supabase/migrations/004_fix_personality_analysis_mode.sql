-- Align the existing Supabase schema with the current personality analysis API.
-- The previous initial migration retained obsolete RULE/LLM values.
ALTER TABLE survey_response
    DROP CONSTRAINT IF EXISTS survey_response_analysis_mode_check;

ALTER TABLE survey_response
    DROP CONSTRAINT IF EXISTS ck_survey_analysis_mode;

ALTER TABLE survey_response
    DROP CONSTRAINT IF EXISTS ck_survey_response_analysis_mode;

ALTER TABLE survey_response
    ADD CONSTRAINT ck_survey_response_analysis_mode
        CHECK (analysis_mode IS NULL OR analysis_mode IN ('INITIAL', 'REANALYSIS'));
