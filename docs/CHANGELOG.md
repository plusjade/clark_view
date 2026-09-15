# Changelog

Record of significant decisions and *why* they were made. Entries describe decisions
at the time; verify current behavior against the owning code, live diagnostics when
relevant, and orientation docs in `docs/`.
Newest entries on top. Use one concise, dated entry: what + why, with an optional
pointer. Preserve historical meaning; record reversals as new entries. Typo and
broken-link corrections are allowed. See [AGENTS.md](../AGENTS.md#documenting-decisions)
for routing current guidance, operational evidence, and routine validation.

## 2026-09-15

- Replaced the shared browser header's Devices/Sources links with Home and a
  horizontally scrolling device gallery, making device switching direct on phones
  while retaining the root jump-off page. Parent `render/pageShell.ts` owns the
  styling and escaped markup; `main.ts` supplies navigation data for HTML only
  (parent main snapshot 338).

- Decoupled device/source assignments from bunch membership. The old
  `device_bunch_move` trigger silently deleted configuration on a bunch change;
  removed it and related cross-bunch guards, including source selection/attachment
  filters. Bunches organize enrollment, not assignment ownership. Parent
  `tools/remove-assignment-bunch-constraints.ts` owns the migration;
  `tools/assignment-bunch-check.ts` reproduced the deletion before migration and
  verifies preservation, cross-bunch operations, and deletion cascades afterward.

- Split device browser administration into Preview (resource root), Sources,
  Presentation, and Settings tabs so opening a device shows its composed feed.
  Settings owns device metadata, name editing, and the merge entry; source removal
  returns to the assignment index. Removed the former preview subroute and retained
  the device name as the preview heading. Implementation: parent
  `http/routes/devices.ts` and `render/deviceHtml.tsx`.

## 2026-09-12

- Added an `add-entry:` agent fast path, initially for `source-gtb`: repository
  guidance routes directly to the target val's `AGENTS.md`, which owns input
  normalization and an insert/read-back SQLite transaction. This deliberately
  bypasses broad orientation and the source write API for a minimal-context data
  entry proof of concept. Success means verified persistence; exact retries are
  idempotent and same-date conflicts preserve the existing row.

- Renamed GTB's SQLite `timestamp` column to `starts_at` after the window rollout,
  aligning storage with `expires_at` and the wire model. The earlier additive
  migration no longer needs the legacy column name; source main snapshot 9 updates
  reads, rebuilds, and schema provisioning without changing stored values.

- Migrated `plusjade/source-gtb` to SDK snapshot 12 and explicit item windows.
  Backfilled all 13 stored reminders with expiry one hour after their existing
  start, preserving custom text and dates; rebuilds now persist the same duration.
  Retained the SQLite `timestamp` column as the start to keep the migration additive.
  The source's `README.md`, `check.ts`, and `http-check.ts` own the storage mapping
  and verification; deployed in main snapshot 8.

## 2026-09-10

- Replaced the item's single `timestamp` with a required `startsAt`/`expiresAt`
  window (widget schema 3, SDK snapshot 12) so lifecycle is derived from the clock
  instead of a stored status that only moves when someone ingests. `expiresAt` is a
  source-owned estimate and is never displayed; the widget uses it only to schedule
  its next refresh on the next bound. An instantaneous event publishes a one-second
  window rather than a null, because a nullable expiry fails silently in both JS
  (`now > null`) and SQL (`expires_at > :now`). The name is `expiresAt`, not
  `endsAt`, because the two bounds are not symmetric in use — only the start is
  rendered — and "expires" carries the approximation the field actually has.
- Kept caption authorship in the sources rather than moving it to the parent: the
  staleness the window fixes came from reading an ingest-frozen status, not from
  where the caption is computed, and a source deriving it from `phase()` at read
  time is equally fresh while keeping domain vocabulary out of a parent that has no
  games model. A stored `final` still outranks the estimated expiry.
- Added a rectangular Lock Screen proof of concept using the existing widget identity
  and provider, plus Beacon's shared date/status view, to keep layout iteration local
  without introducing another feed or refresh path. See [iteration guide](lock-screen-widget.md).
- Added scoped operational evidence and preserved verification pointers in documentation
  routing because removing provenance can make temporary observations look permanent.
- Consolidated current guidance and introduced decision routing because completed
  migration narratives were being mistaken for current system behavior.
