-- ══════════════════════════════════════════════════════════════════════════
-- 2026-09-22 — egg_settings: allocate a customer at setting time, and link
--              the resulting hatch to the DOC Tracker record it produces
--
-- STATUS: NOT YET APPLIED — run this before deploying the HatcheryOS build
--         that writes these columns.
--
-- Why
--   HatcheryOS decides which eggs go to which customer when the eggs are set,
--   not after they hatch (user's choice: "ผูกกับไข่ตั้งแต่แรก"). So the
--   customer has to live on egg_settings from the moment the batch starts.
--
--   When the hatch is completed, HatcheryOS writes one doc_records row for
--   that customer — forecast_doc becomes the ordered quantity and actual_doc
--   the delivered quantity, so DOC Tracker's Order vs Actual works out of the
--   box. doc_record_id remembers which row was created so completing a hatch
--   twice cannot produce two orders.
--
--   Customer values mirror DOC Tracker's own columns (customers.customer_name
--   / customer_type / customer_code) so nothing needs translating at the
--   boundary. Breed does need translating — see toDocBreed() in the app.
-- ══════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE public.egg_settings
  ADD COLUMN IF NOT EXISTS customer_name text,
  ADD COLUMN IF NOT EXISTS customer_type text,
  ADD COLUMN IF NOT EXISTS customer_code text,
  ADD COLUMN IF NOT EXISTS doc_record_id  uuid;

-- Deliberately ON DELETE SET NULL, not CASCADE: deleting an order in DOC
-- Tracker must never delete the incubation history that produced it.
DO $fk$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'egg_settings_doc_record_id_fkey'
      AND conrelid = 'public.egg_settings'::regclass
  ) THEN
    ALTER TABLE public.egg_settings
      ADD CONSTRAINT egg_settings_doc_record_id_fkey
      FOREIGN KEY (doc_record_id) REFERENCES public.doc_records(id) ON DELETE SET NULL;
  END IF;
END
$fk$;

CREATE INDEX IF NOT EXISTS egg_settings_customer_idx
  ON public.egg_settings (customer_name);

CREATE INDEX IF NOT EXISTS egg_settings_doc_record_idx
  ON public.egg_settings (doc_record_id)
  WHERE doc_record_id IS NOT NULL;

COMMIT;


-- ── VERIFY ────────────────────────────────────────────────────────────────
-- SELECT column_name, data_type
-- FROM information_schema.columns
-- WHERE table_schema='public' AND table_name='egg_settings'
--   AND column_name IN ('customer_name','customer_type','customer_code','doc_record_id')
-- ORDER BY column_name;


-- ── DOWN ──────────────────────────────────────────────────────────────────
-- Drops the allocation data as well, so only roll back if the columns were
-- never filled in.
--
-- BEGIN;
-- DROP INDEX IF EXISTS public.egg_settings_doc_record_idx;
-- DROP INDEX IF EXISTS public.egg_settings_customer_idx;
-- ALTER TABLE public.egg_settings
--   DROP CONSTRAINT IF EXISTS egg_settings_doc_record_id_fkey,
--   DROP COLUMN IF EXISTS doc_record_id,
--   DROP COLUMN IF EXISTS customer_code,
--   DROP COLUMN IF EXISTS customer_type,
--   DROP COLUMN IF EXISTS customer_name;
-- COMMIT;
