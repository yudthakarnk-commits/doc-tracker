-- ══════════════════════════════════════════════════════════════════════════
-- 2026-09-22 — week targets and estimates must carry a year
--
-- STATUS: NOT YET APPLIED
--
-- The bug
--   doc_targets_unique is (period_type, target_date, target_week, customer_type)
--   NULLS NOT DISTINCT, and week rows leave target_date NULL. Because those
--   NULLs compare equal, (week 40, Customer) can exist exactly once in the whole
--   table, whatever year it belongs to. The first 2027 target set for a week that
--   already has a 2026 one would overwrite it through saveTarget's upsert —
--   silently, no error.
--
--   hatchery_estimates has the identical shape and the identical bug.
--
--   Nothing is lost yet: 74 week rows, 18,383,600 booking, all created in 2026
--   covering W14–W40 of 2026.
--
-- The fix
--   Week rows store the Monday of their ISO week in target_date. target_date is
--   already part of the unique key, so 2026-W40 and 2027-W40 separate themselves
--   and the unique index does not have to be rebuilt on a table in daily use.
--
-- What the first attempt got wrong
--   The first version of this file was the backfill alone. It failed on
--   period_field_required, a CHECK that requires a week row to have target_date
--   NULL — precisely the assumption causing the bug. Only the unique indexes had
--   been examined, not the CHECK constraints. The transaction rolled back and no
--   data changed. Triggers were checked this time too: there are none on either
--   table.
--
-- Order matters
--   Relax the constraint, then backfill, then deploy the web app — in that
--   order. Doing it the other way round leaves the deployed app writing rows the
--   database rejects, and saveTarget deletes the undated row before upserting
--   the dated one, so a failed insert loses the original target.
-- ══════════════════════════════════════════════════════════════════════════


-- ── UP ────────────────────────────────────────────────────────────────────
-- One transaction: either the rule changes and the rows are filled in, or
-- nothing happens at all.
--
-- The day branch is copied verbatim from the existing constraint. The week
-- branch drops only "AND target_date IS NULL".
--
-- The week branch says target_date MAY be set, not MUST — existing rows are
-- still NULL at the moment ADD CONSTRAINT validates them, and requiring it
-- would fail on every one of the 74.

BEGIN;

ALTER TABLE public.doc_targets DROP CONSTRAINT period_field_required;
ALTER TABLE public.doc_targets ADD CONSTRAINT period_field_required CHECK (
  ((period_type = 'day'::text)  AND (target_date IS NOT NULL) AND (target_week IS NULL)) OR
  ((period_type = 'week'::text) AND (target_week IS NOT NULL))
);

ALTER TABLE public.hatchery_estimates DROP CONSTRAINT period_field_required;
ALTER TABLE public.hatchery_estimates ADD CONSTRAINT period_field_required CHECK (
  ((period_type = 'day'::text)  AND (target_date IS NOT NULL) AND (target_week IS NULL)) OR
  ((period_type = 'week'::text) AND (target_week IS NOT NULL))
);

-- date_trunc('week', …) returns the Monday. Jan 4th is always in ISO week 1,
-- so this lands on the Monday of week 1 and counts whole weeks from there.
-- Year 2026 for every row: verified, not assumed — every week row was created
-- in 2026 (28 Apr – 5 Sep) and created_at tracks target_week (W14–W21 entered
-- together on 28 Apr, W22 on 22 May, up to W40 in Sep). No forward planning
-- into 2027 to mistake for the current year.

UPDATE public.doc_targets
SET target_date = (date_trunc('week', make_date(2026, 1, 4))
                   + (target_week - 1) * interval '7 day')::date
WHERE period_type = 'week' AND target_week IS NOT NULL AND target_date IS NULL;

UPDATE public.hatchery_estimates
SET target_date = (date_trunc('week', make_date(2026, 1, 4))
                   + (target_week - 1) * interval '7 day')::date
WHERE period_type = 'week' AND target_week IS NOT NULL AND target_date IS NULL;

COMMIT;


-- ── VERIFY ────────────────────────────────────────────────────────────────
-- Expect 74 rows, 18383600 booking, 0 missing dates, W14 → 2026-03-30 and
-- W40 → 2026-09-28.
--
-- SELECT count(*)                                        AS week_rows,
--        sum(booking)                                    AS total_booking,
--        count(*) FILTER (WHERE target_date IS NULL)     AS still_missing_date,
--        min(target_date)                                AS earliest,
--        max(target_date)                                AS latest
-- FROM doc_targets WHERE period_type = 'week';


-- ── DOWN ──────────────────────────────────────────────────────────────────
-- Only safe while every week row is still 2026. Once 2027 targets exist,
-- clearing target_date makes them collide with their 2026 counterparts and the
-- next upsert overwrites one of them.
--
-- BEGIN;
-- UPDATE public.doc_targets        SET target_date = NULL WHERE period_type = 'week';
-- UPDATE public.hatchery_estimates SET target_date = NULL WHERE period_type = 'week';
-- ALTER TABLE public.doc_targets DROP CONSTRAINT period_field_required;
-- ALTER TABLE public.doc_targets ADD CONSTRAINT period_field_required CHECK (
--   ((period_type = 'day'::text)  AND (target_date IS NOT NULL) AND (target_week IS NULL)) OR
--   ((period_type = 'week'::text) AND (target_week IS NOT NULL) AND (target_date IS NULL))
-- );
-- ALTER TABLE public.hatchery_estimates DROP CONSTRAINT period_field_required;
-- ALTER TABLE public.hatchery_estimates ADD CONSTRAINT period_field_required CHECK (
--   ((period_type = 'day'::text)  AND (target_date IS NOT NULL) AND (target_week IS NULL)) OR
--   ((period_type = 'week'::text) AND (target_week IS NOT NULL) AND (target_date IS NULL))
-- );
-- COMMIT;
