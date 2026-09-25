-- ══════════════════════════════════════════════════════════════════════════
-- 2026-09-25 — farm_houses: which breed each house holds
--
-- STATUS: NOT YET APPLIED
--
-- Why
--   Breed was a column in the egg lot import template, typed on every row. It
--   is not per-lot information: a house holds one breed, so the same value was
--   being retyped constantly and a typo there silently changes the hatchability
--   standard used for that lot, and with it the DOC forecast.
--
--   The import now looks the breed up from (farm, house) and fills it in.
--   Breed stays in the template as an optional override, used for Farm =
--   External where the eggs come from outside and there is no house to look up.
--
-- UNIQUE (farm, house)
--   Deliberate here, unlike doc_records and egg_sales where a tight key blocked
--   real duplicates. A house has exactly one current breed — that is the whole
--   premise of the lookup — so two rows for one house would make the fill
--   ambiguous and there is no legitimate case for it. When a house changes over
--   to another breed, the row is edited rather than a second one added.
--
--   That does mean the reference holds the CURRENT breed only. Importing old
--   receipts for a house that has since switched breed would fill the new one,
--   so the import preview shows the filled breed on every row for checking
--   before anything is written.
-- ══════════════════════════════════════════════════════════════════════════


-- ── UP ────────────────────────────────────────────────────────────────────

BEGIN;

CREATE TABLE IF NOT EXISTS public.farm_houses (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm       text NOT NULL,
  house      text NOT NULL,          -- เล้า
  breed      text NOT NULL,
  notes      text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz,
  CONSTRAINT farm_houses_farm_house_key UNIQUE (farm, house)
);

-- Breed values must stay in step with BREEDS in hatchery-os.html; the STD
-- hatchability tables are keyed by exactly these strings.
ALTER TABLE public.farm_houses DROP CONSTRAINT IF EXISTS farm_houses_breed_check;
ALTER TABLE public.farm_houses ADD CONSTRAINT farm_houses_breed_check
  CHECK (breed = ANY (ARRAY['Ross 308'::text, 'Cobb 500'::text, 'Custom'::text]));

ALTER TABLE public.farm_houses ENABLE ROW LEVEL SECURITY;

-- Same two policies as farm_egg_plan and egg_sales.
DROP POLICY IF EXISTS "Authenticated read farm_houses"  ON public.farm_houses;
DROP POLICY IF EXISTS "Authenticated write farm_houses" ON public.farm_houses;

CREATE POLICY "Authenticated read farm_houses"
  ON public.farm_houses FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Authenticated write farm_houses"
  ON public.farm_houses FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

COMMIT;


-- ── VERIFY ────────────────────────────────────────────────────────────────
-- SELECT count(*) FROM public.farm_houses;            -- 0, no permission error
-- SELECT policyname, cmd FROM pg_policies
-- WHERE schemaname='public' AND tablename='farm_houses';   -- 2 rows


-- ── DOWN ──────────────────────────────────────────────────────────────────
-- DROP TABLE IF EXISTS public.farm_houses;
