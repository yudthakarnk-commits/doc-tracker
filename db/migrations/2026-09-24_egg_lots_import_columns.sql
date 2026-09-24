-- ══════════════════════════════════════════════════════════════════════════
-- 2026-09-24 — egg_lots: DO number, house, flock, and import batches
--
-- STATUS: NOT YET APPLIED
--
-- Why
--   Bulk import of egg receipts and remaining stock, to fill HE Delivery and
--   Cool Room Stock from a flat spreadsheet. Both pages read egg_lots, so one
--   import serves both.
--
--   house and flock are not new information: parseDOExcel already reads them
--   off the delivery form and then throws them away, because there was nowhere
--   to put them. do_number is the same story.
--
--   import_batch groups the rows written by one import so a mistaken one can be
--   removed in a single statement. Without it, undoing means picking rows out by
--   hand and hoping none were missed.
--
-- Checked first, per db/queries/inspect.sql
--   egg_lots has exactly one CHECK constraint, egg_lots_status_check on status,
--   and no CHECK enumerating hatchery, farm or breed — so Kota, added to the app
--   on 2026-09-22, is accepted here. No triggers.
--
--   All four columns are nullable with no default, so ADD COLUMN validates
--   nothing against existing rows and the existing status CHECK is untouched.
-- ══════════════════════════════════════════════════════════════════════════


-- ── UP ────────────────────────────────────────────────────────────────────

BEGIN;

ALTER TABLE public.egg_lots
  ADD COLUMN IF NOT EXISTS do_number    text,
  ADD COLUMN IF NOT EXISTS house        text,   -- เล้า
  ADD COLUMN IF NOT EXISTS flock        text,   -- ฝูง
  ADD COLUMN IF NOT EXISTS import_batch uuid;

-- Undo looks lots up by batch and nothing else.
CREATE INDEX IF NOT EXISTS egg_lots_import_batch_idx
  ON public.egg_lots (import_batch)
  WHERE import_batch IS NOT NULL;

COMMIT;

-- Deliberately NO unique constraint over (recv_date, farm, hatchery, breed, wop).
-- The same farm can send the same breed and WOP to the same hatchery twice in one
-- day, from different houses — doc_records was keyed that tightly and blocked a
-- real second lorry on 2026-09-18. The import warns about rows that look like a
-- repeat and lets the person decide, and import_batch makes a wrong call cheap to
-- reverse.


-- ── VERIFY ────────────────────────────────────────────────────────────────
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_schema='public' AND table_name='egg_lots'
--   AND column_name IN ('do_number','house','flock','import_batch')
-- ORDER BY column_name;


-- ── DOWN ──────────────────────────────────────────────────────────────────
-- Drops the imported detail with the columns, so only roll back if nothing has
-- been imported yet.
--
-- BEGIN;
-- DROP INDEX IF EXISTS public.egg_lots_import_batch_idx;
-- ALTER TABLE public.egg_lots
--   DROP COLUMN IF EXISTS import_batch,
--   DROP COLUMN IF EXISTS flock,
--   DROP COLUMN IF EXISTS house,
--   DROP COLUMN IF EXISTS do_number;
-- COMMIT;
