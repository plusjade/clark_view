# SQLite selection catalog

Deployed 2026-09-06 to both `plusjade/sports-today` and
`plusjade/sports-today-device-feed`. The canonical tables live only in the
**device-feed val's SQLite database**. The parent reads them through authenticated
`GET /catalog` on the existing provider RPC endpoint.

| Table | Identity and purpose |
| --- | --- |
| `catalog_competitions` | `code` is the existing normalized game sport key (`nfl`, `cfb`, `wnba`, `nba`, `fiba`). Stores display name, display order, adapter, provider competition key, emoji, and coverage note. |
| `catalog_teams` | `slug` is the existing assignment identifier. References its competition and stores an independent display name, provider team code, and display order within that competition. |

These are competitions rather than physical sports: NFL and CFB are both
football; NBA, WNBA and the current FIBA tournament are basketball. A team row
means a selectable participant in one competition, not a universal franchise or
national-team identity. The current requirement does not need a separate sport
taxonomy, franchise registry, season table, or multiple provider aliases per team.

`UNIQUE (competition_code, provider_team_code)` prevents two selection slugs from
silently resolving to the same team. Codes can repeat across competitions: WNBA
`IND` means Fever and NFL `IND` means Colts. Slugs remain globally unique because
existing assignment settings are arrays of those slugs. Display names can now be
changed independently of slugs, including capitalization and punctuation.

Both levels have explicit display ordering with stable key tie-breakers. Seeded
order, labels and all 67 mappings match the former catalog: NFL 32, CFB 2, WNBA 15,
NBA 2, FIBA 16. Coverage notes distinguish complete league selections from curated
subsets and identify FIBA as the **2026 Women's World Cup roster**, not a permanent
international basketball catalog. That note is context for operators, not an
automatic expiry rule.

## Reading and extending it

The provider's `lib/catalog.ts` contains only domain types. `lib/catalogStore.ts`
reads the two tables in one read transaction. A Games request passes that snapshot
to pure parameter resolution, matching, and rendering. Sleeper ingest also derives
its requested competition keys from SQLite and translates them to the stable game
keys. The parent parses the RPC response before using it in forms and validation.
No module-load query, mutable global catalog, or runtime seed is involved; edits
are visible on the next request.

To add a team in an existing competition, insert one `catalog_teams` row using
parameterized SQL:

```sql
INSERT INTO catalog_teams
  (slug, competition_code, display_name, provider_team_code, display_order)
VALUES (?, ?, ?, ?, ?);
```

Choose a globally unique stable slug, a verified provider code, the desired label,
and a nonnegative position within its competition. The team becomes selectable and
resolvable without deploying either val. It still needs ingested game coverage to
produce an event. Correct a label with `UPDATE ... SET display_name = ? WHERE
slug = ?`; do not rename the slug merely to change what the user sees.

A new Sleeper competition needs a competition row and its selected team rows,
plus verification of the adapter's incoming data shape. A new data provider needs
an implemented adapter and a deliberate extension of the adapter constraint.
The existing `fiba` adapter remains specific to the current ESPN bucket and
normalizes to the `fiba` game key; adding a different FIBA tournament is an adapter
change, not simply another competition row. Revalidate ESPN's bucket before reuse.

Assignments remain JSON in the parent's database. There is intentionally no
cross-database foreign key: parent writes filter against the RPC catalog, while
the provider independently resolves every requested slug. Removing or renaming a
referenced slug therefore requires checking and updating assignments first.
Unknown selections retain the existing rejection behavior. Catalog read failures
fail the request instead of masquerading as a valid empty catalog and discarding
all submitted selections.

Broadcaster labels, DirecTV numbers and channel matching remain provider display
rules in `lib/channels.ts`; they are separate from the selection catalog migrated
here. Input limits remain code policy (`MAX_TEAMS = 120` in `lib/params.ts`).

## Migration and checks

The complete schema and initial seed are in [catalog-schema.sql](catalog-schema.sql)
and the provider's `migrations/001-catalog.sql`. They were applied atomically to
the provider database before switching readers. The seed inserts missing primary
keys and preserves operator edits on rerun; rerunning it can restore deleted seed
rows, so it is an explicit bootstrap/migration tool, never normal request setup.
The parent has no duplicate catalog tables or runtime seed data.

Both vals retain a read-only `tools/catalog-check.ts`. The provider check covers
the initial mappings, scoped codes, normalization, explicit labels, empty
selection, widget-v2 output, SQLite reads and RPC authentication. The parent check
covers the RPC guard, all picker options, escaped labels, ordering and checked
selections. The seed-preservation assertions are a migration baseline; intentional
future catalog changes may require updating those assertions.

Local SQLite verification covered foreign keys, scoped uniqueness, invalid display
positions and non-overwriting seed reruns. Live verification confirmed the picker
returns 67 choices and `/config/resolve` matches the pre-migration response. That
live starter feed was empty before and after; populated rendering was verified
separately with a deterministic game fixture. Widget schema and endpoint identity
remain unchanged.
