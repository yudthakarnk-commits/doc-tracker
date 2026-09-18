# Database notes

The schema lives in **Supabase** (`ncnppcmlxdaabuwkcbtm`), not in this repo — there is no
migration tool wired up. This folder exists so that rules which are invisible from the
application code still leave a trail.

**It is not a full schema dump.** Only what has been verified against the live database is
recorded here. If you add or change something in the Supabase SQL editor, add a file under
`migrations/` in the same style.

## Layout

| Path | What it is |
|---|---|
| `migrations/` | Changes applied to production, newest last. Each file has the change and its rollback. |
| `queries/inspect.sql` | Read-only queries for answering "why won't this row save?" |

## The one rule that bites

`doc_records` has a unique index, **`doc_records_unique_idx`**, that both frontends can trip
without any hint in the code — a plain `.insert()` comes back as SQLSTATE 23505. It keys on
the **ordered quantities** as well as the obvious columns, which is the surprising part.

Both frontends translate 23505 into a readable message rather than showing the raw Postgres
text — `dbErrMsg()` in `index.html` and in `flutter_app/lib/i18n.dart` (since app v1.3.1).

## Reading a long index definition

The Supabase SQL editor truncates long result cells, so `SELECT indexdef ...` is unreadable
for anything non-trivial. Split it into short rows instead — see `queries/inspect.sql`.
