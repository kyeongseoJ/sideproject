-- Remove the legacy survey field. Current personality analysis does not
-- accept, persist, or read an energy-level answer.
ALTER TABLE survey_response
    DROP COLUMN IF EXISTS energy_level;
