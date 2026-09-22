-- ══════════════════════════════════════════════════════════════════════════
-- 2026-09-22 — week targets and estimates must carry a year
--
-- STATUS: NOT YET APPLIED
--
-- The bug
--   doc_targets_unique is (period_type, target_date, target_week, customer_type)
--   NULLS NOT DISTINCT. Week rows leave target_date NULL, and NULLS NOT DISTINCT
--   makes those NULLs compare equal — so (week 40, Customer) can exist exactly
--   once in the whole table, whatever year it belongs to.
--
--   Nothing has been lost yet: all 74 week rows were created in 2026 and cover
--   W14–W40 of 2026. But the first time someone sets a 2027 target for a week
--   that already has a 2026 one, saveTarget's upsert overwrites it silently —
--   no error, no warning, last year's target simply gone.
--
--   hatchery_estimates_unique has the identical shape and the identical bug.
--
-- The fix
--   Fill target_date with the Monday of that ISO week. target_date is already
--   part of the unique key, so 2026-W40 and 2027-W40 become distinct rows on
--   their own — no index or constraint has to change, which is why this is a
--   plain UPDATE rather than a DDL migration on a table in daily use.
--
--   The app writes target_date for new week rows from this build onward, and
--   readers treat a NULL target_date as "matches any year" so rows that predate
--   the backfill keep working.
--
-- Year assignment
--   2026 for every existing row. Verified, not assumed: every week row was
--   created in 2026 (28 Apr – 5 Sep), and created_at tracks target_week —
--   W14–W21 entered together on 28 Apr, W22 on 22 May, and so on up to W40.
--   There is no forward planning into 2027 to mistake for the current year.
-- ══════════════════════════════════════════════════════════════════════════


-- ── UP ────────────────────────────────────────────────────────────────────
-- date_trunc('week', …) returns the Monday. Jan 4th is always in ISO week 1,
-- so this lands on the Monday of week 1 and counts whole weeks from there.

BEGIN;

UPDATE public.doc_targets
SET target_date = (date_trunc('week', make_date(2026, 1, 4))
                   + (target_week - 1) * interval '7 day')::date
WHERE period_type = 'week'
  AND target_week IS NOT NULL
  AND target_date IS NULL;

UPDATE public.hatchery_estimates
SET target_date = (date_trunc('week', make_date(2026, 1, 4))
                   + (target_week - 1) * interval '7 day')::date
WHERE period_type = 'week'
  AND target_week IS NOT NULL
  AND target_date IS NULL;

COMMIT;


-- ── VERIFY ────────────────────────────────────────────────────────────────
-- Expect 74 doc_targets rows, W14 → 2026-03-30 and W40 → 2026-09-28,
-- and no remaining NULLs.
--
-- SELECT 'doc_targets' AS tbl, target_week, target_date, count(*) AS rows
-- FROM doc_targets WHERE period_type='week'
-- GROUP BY 1,2,3 ORDER BY target_week
-- LIMIT 5;
--
-- SELECT count(*) AS still_null
-- FROM doc_targets WHERE period_type='week' AND target_date IS NULL;


-- ── DOWN ──────────────────────────────────────────────────────────────────
-- Safe only while every week row is still 2026 — once 2027 targets exist,
-- clearing target_date would make them collide with their 2026 counterparts
-- and the next upsert would overwrite one of them.
--
-- BEGIN;
-- UPDATE public.doc_targets       SET target_date = NULL WHERE period_type = 'week';
-- UPDATE public.hatchery_estimates SET target_date = NULL WHERE period_type = 'week';
-- COMMIT;
