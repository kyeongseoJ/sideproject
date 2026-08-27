-- Ensure the shared BASE catalog includes the full 5-minute to 3-hour range.
-- The deterministic selection keeps this migration idempotent.
UPDATE mission
   SET estimated_minutes = 180
 WHERE mission_id = (
       SELECT MAX(mission_id)
         FROM mission
        WHERE source_type = 'BASE'
          AND enabled = 'Y'
   );
