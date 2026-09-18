-- ══════════════════════════════════════════════════════════════════════════
-- 2026-09-18 — doc_records_unique_idx: allow more than one lorry per
--              customer per day
--
-- APPLIED TO PRODUCTION: 2026-09-18
--
-- Problem
--   Donlark took delivery on two lorries in one day. The second record was
--   rejected with:
--       duplicate key value violates unique constraint "doc_records_unique_idx"
--
--   The index keyed on the ordered quantities but not on anything that
--   distinguishes one trip from another. Two lorries for the same customer,
--   date and hatchery with the SAME ordered quantities collided. It had gone
--   unnoticed for months only because the two lorries usually had different
--   ordered amounts — the database already held 9 such customer/day pairs
--   that had slipped through that way.
--
-- Fix
--   Add do_number and truck_plate to the key. The new rule is a superset of
--   the old one, so every existing row that satisfied the old index also
--   satisfies the new one and creation cannot fail on existing data.
--
--   Re-importing the same Excel file is still blocked: the import template
--   has a Truck Plate column, so a repeated file carries identical values
--   and still collides. (It has no DO Number column — that stays NULL, and
--   COALESCE maps it to '' so NULLs compare equal rather than being treated
--   as distinct.)
--
--   Trade-off: two lorries with BOTH do_number and truck_plate left blank are
--   still rejected. That is intentional — a second trip has to say which trip
--   it is.
-- ══════════════════════════════════════════════════════════════════════════


-- ── BEFORE ────────────────────────────────────────────────────────────────
-- NOTE: the first 9 of the 11 split rows were read directly; the pair making
-- up COALESCE(u_ordered, 0) is reconstructed from the row count (3 plain
-- columns + 4 COALESCE = 11 before, + 2 COALESCE = 15 after, both observed).
-- Confirm with query 1 in ../queries/inspect.sql and delete this note.
--
-- CREATE UNIQUE INDEX doc_records_unique_idx ON public.doc_records USING btree (
--   record_date,
--   hatchery,
--   customer_name,
--   COALESCE(breed, ''::text),
--   COALESCE(m_ordered, 0),
--   COALESCE(f_ordered, 0),
--   COALESCE(u_ordered, 0)
-- );


-- ── UP ────────────────────────────────────────────────────────────────────
-- What actually ran derived the new definition from the old one rather than
-- retyping it, so that nothing could be lost to the SQL editor truncating the
-- cell. The result is equivalent to the AFTER block below.

BEGIN;

DO $mig$
DECLARE olddef text; newdef text;
BEGIN
  SELECT indexdef INTO olddef FROM pg_indexes
  WHERE schemaname = 'public' AND indexname = 'doc_records_unique_idx';

  IF olddef IS NULL THEN
    RAISE EXCEPTION 'index doc_records_unique_idx not found';
  END IF;
  IF right(olddef, 1) <> ')' THEN
    RAISE EXCEPTION 'unexpected index shape (partial index?): %', olddef;
  END IF;
  IF olddef LIKE '%do_number%' OR olddef LIKE '%truck_plate%' THEN
    RAISE EXCEPTION 'already migrated: %', olddef;
  END IF;

  newdef := regexp_replace(
              replace(olddef, ' doc_records_unique_idx ', ' doc_records_unique_idx_new '),
              '\)$',
              ', COALESCE(do_number, ''''::text), COALESCE(truck_plate, ''''::text))');

  EXECUTE newdef;
END
$mig$;

DROP INDEX public.doc_records_unique_idx;
ALTER INDEX public.doc_records_unique_idx_new RENAME TO doc_records_unique_idx;

COMMIT;


-- ── AFTER ─────────────────────────────────────────────────────────────────
-- CREATE UNIQUE INDEX doc_records_unique_idx ON public.doc_records USING btree (
--   record_date,
--   hatchery,
--   customer_name,
--   COALESCE(breed, ''::text),
--   COALESCE(m_ordered, 0),
--   COALESCE(f_ordered, 0),
--   COALESCE(u_ordered, 0),
--   COALESCE(do_number, ''::text),
--   COALESCE(truck_plate, ''::text)
-- );


-- ── DOWN ──────────────────────────────────────────────────────────────────
-- Strips only the two expressions this migration added, so it does not depend
-- on the rest of the definition being what we think it is.

-- BEGIN;
--
-- DO $rb$
-- DECLARE cur text; back text;
-- BEGIN
--   SELECT indexdef INTO cur FROM pg_indexes
--   WHERE schemaname = 'public' AND indexname = 'doc_records_unique_idx';
--
--   IF cur NOT LIKE '%, COALESCE(do_number, ''''::text), COALESCE(truck_plate, ''''::text))' THEN
--     RAISE EXCEPTION 'not in the migrated shape, refusing to roll back: %', cur;
--   END IF;
--
--   back := replace(
--             replace(cur, ', COALESCE(do_number, ''''::text), COALESCE(truck_plate, ''''::text))', ')'),
--             ' doc_records_unique_idx ', ' doc_records_unique_idx_old ');
--   EXECUTE back;
-- END
-- $rb$;
--
-- DROP INDEX public.doc_records_unique_idx;
-- ALTER INDEX public.doc_records_unique_idx_old RENAME TO doc_records_unique_idx;
--
-- COMMIT;
