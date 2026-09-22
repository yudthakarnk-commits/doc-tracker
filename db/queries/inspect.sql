-- Read-only queries. Nothing here changes data.
-- Paste one block at a time into the Supabase SQL editor.


-- ══════════════════════════════════════════════════════════════════════════
-- 1. Read a unique index definition without the editor truncating it
--
-- The SQL editor cuts off long result cells, so plain `SELECT indexdef` is
-- unreadable. Splitting on ', ' gives one short row per piece. A COALESCE
-- lands across two rows because of the comma inside it — that is expected.
-- ══════════════════════════════════════════════════════════════════════════

SELECT u.ordinality AS n, u.part
FROM pg_indexes,
     LATERAL unnest(string_to_array(indexdef, ', ')) WITH ORDINALITY AS u(part, ordinality)
WHERE indexname = 'doc_records_unique_idx'
ORDER BY 1;


-- ══════════════════════════════════════════════════════════════════════════
-- 1b. EVERY rule on a table, before designing any migration
--
-- Run all three. A migration was written once against the unique indexes alone
-- and failed on a CHECK nobody had looked at — after the app that depended on
-- it had already shipped. Indexes, CHECK constraints and triggers, every time.
--
-- Set the table list once and reuse it in all three.
-- ══════════════════════════════════════════════════════════════════════════

-- indexes
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public' AND tablename IN ('doc_targets', 'hatchery_estimates');

-- check constraints, split so the editor cannot truncate them
SELECT conrelid::regclass AS tbl, conname, u.ordinality AS n, u.part
FROM pg_constraint,
     LATERAL unnest(string_to_array(pg_get_constraintdef(oid), ' AND ')) WITH ORDINALITY AS u(part, ordinality)
WHERE conrelid IN ('public.doc_targets'::regclass, 'public.hatchery_estimates'::regclass)
  AND contype = 'c'
ORDER BY 1, 2, 3;

-- triggers
SELECT event_object_table AS tbl, trigger_name, action_timing, event_manipulation
FROM information_schema.triggers
WHERE event_object_table IN ('doc_targets', 'hatchery_estimates')
ORDER BY 1, 2;


-- ══════════════════════════════════════════════════════════════════════════
-- 2. Every unique rule on doc_records
-- ══════════════════════════════════════════════════════════════════════════

SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'doc_records' AND indexdef LIKE '%UNIQUE%';


-- ══════════════════════════════════════════════════════════════════════════
-- 3. Would a proposed key have collisions in the existing data?
--
-- Run this BEFORE creating any new unique index — CREATE fails if it returns
-- rows, and this tells you which rows are in the way. Edit the column list to
-- match the key you are considering.
-- ══════════════════════════════════════════════════════════════════════════

SELECT record_date, hatchery, customer_name, customer_type, breed,
       do_number, truck_plate, count(*)
FROM doc_records
GROUP BY 1, 2, 3, 4, 5, 6, 7
HAVING count(*) > 1
ORDER BY 1 DESC;


-- ══════════════════════════════════════════════════════════════════════════
-- 4. Which rows are genuinely a second trip for the same customer and day?
--
-- Useful for sanity-checking that multi-lorry days look the way the team
-- describes them.
-- ══════════════════════════════════════════════════════════════════════════

SELECT record_date, hatchery, customer_name,
       count(*)                                        AS trips,
       count(*) FILTER (WHERE do_number   IS NOT NULL) AS with_do,
       count(*) FILTER (WHERE truck_plate IS NOT NULL) AS with_plate
FROM doc_records
GROUP BY 1, 2, 3
HAVING count(*) > 1
ORDER BY 1 DESC;
