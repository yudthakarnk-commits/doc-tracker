-- ══════════════════════════════════════════════════════════════════════════
-- 2026-09-22 — egg_sales: eggs sold off instead of being set
--
-- STATUS: NOT YET APPLIED
--
-- RLS mirrors farm_egg_plan exactly, read from pg_policies: one SELECT policy
-- and one ALL policy, both for the authenticated role with a plain true
-- predicate. Not invented — a table with RLS on and no policy returns zero rows
-- to everyone, which looks like a broken feature rather than a permissions
-- problem.
--
-- Why a table rather than columns on farm_egg_plan
--   A week can have several sales, each from a different farm and house, so it
--   is a repeating detail and does not fit farm_egg_plan's one-column-per-farm
--   shape. Entry needs farm + house + quantity; the supply table only ever
--   shows the weekly total, which is a SUM over these rows.
--
--   week_no is the join back to farm_egg_plan, matching how the rest of the
--   upstream data is keyed. week_end_date is carried along so a sale can be
--   read on its own without looking up the plan row.
-- ══════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS public.egg_sales (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_no       integer NOT NULL,
  week_end_date date,
  farm          text    NOT NULL,
  house         text,                       -- เล้า; free text, houses are not a reference table
  qty_he        integer NOT NULL DEFAULT 0 CHECK (qty_he >= 0),
  notes         text,
  created_by    uuid,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- The supply table groups by week, and the modal loads one week at a time.
CREATE INDEX IF NOT EXISTS egg_sales_week_idx ON public.egg_sales (week_no);

-- No unique constraint on (week_no, farm, house): the same house can legitimately
-- be sold from more than once in a week, and forcing uniqueness here would make
-- the second sale silently overwrite the first — the same trap doc_targets fell
-- into with its week rows.

ALTER TABLE public.egg_sales ENABLE ROW LEVEL SECURITY;

-- Same two policies farm_egg_plan has. The ALL policy already covers SELECT;
-- the separate read policy is kept so the pair matches the other tables.
DROP POLICY IF EXISTS "Authenticated read egg_sales"  ON public.egg_sales;
DROP POLICY IF EXISTS "Authenticated write egg_sales" ON public.egg_sales;

CREATE POLICY "Authenticated read egg_sales"
  ON public.egg_sales FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Authenticated write egg_sales"
  ON public.egg_sales FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

COMMIT;


-- ── VERIFY ────────────────────────────────────────────────────────────────
-- SELECT count(*) FROM public.egg_sales;   -- 0, and no permission error
-- SELECT policyname, cmd FROM pg_policies
-- WHERE schemaname='public' AND tablename='egg_sales';


-- ── DOWN ──────────────────────────────────────────────────────────────────
-- DROP TABLE IF EXISTS public.egg_sales;
