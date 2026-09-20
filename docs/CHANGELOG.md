# Changelog

Record of significant decisions and *why* they were made. Entries describe decisions
at the time; verify current behavior against the owning code, live diagnostics when
relevant, and orientation docs in `docs/`.
Newest entries on top. Use one concise, dated entry: what + why, with an optional
pointer. Preserve historical meaning; record reversals as new entries. Typo and
broken-link corrections are allowed. See [AGENTS.md](../AGENTS.md#documenting-decisions)
for routing current guidance, operational evidence, and routine validation.

## 2026-09-20

- Retired source protocol v1 and per-device source settings entirely. All seven
  registered sources had already moved to the canonical GET profile, so the POST
  read, the descriptor/validate/publish conformance branch, and the whole
  descriptor-driven settings stack (`lib/sourceSettings.ts`, the settings forms, the
  source Settings tab) were dead code holding open a contract nobody used. Settings
  are gone for good: an attach carries a source and its Live/Disabled state, and a
  request carrying settings is refused 422 rather than ignored. `sourcePointer` now
  throws on any `read_profile` other than `get-no-settings`, because the column still
  defaults to the retired `v1` and a row that omitted it would otherwise reach a
  removed transport. The `read_transport`, `settings_schema` and
  `device_sources.settings` columns stay inert — `sources` cannot be rebuilt without
  cascading away every assignment, and a NULL settings value would silently drop an
  assignment from the widget feed. Verified by `tools/check.ts` plus a direct read of
  all seven live sources.

- Added one presentation-only `clarkview` route contract across widgets, Live
  Activities, and alert responses. System-surface taps now push the notifying event
  or activity snapshot instead of dropping people on setup; invalid routes do
  nothing, and alert payloads without a route retain useful title/body fallback.
  The route carries no credentials and performs no mutation or server lookup
  (`Shared/AppDeepLink.swift`, `clark_view/DeepLinkRouter.swift`).

## 2026-09-19

- Split the single diagnostics sheet into dedicated Device, Notifications, Widget,
  and Live Activity panels behind one toolbar menu (`clark_view/DiagnosticsPanel.swift`).
  The home screen keeps only setup — pairing and the notification permission prompt —
  so instrumentation grows by adding a panel instead of another section in a list.
- Dropped source settings from the iOS device-status model. The browser owns settings
  editing, so the app renders assigned sources as a plain list of kinds. Decoding them
  was also a liveness risk: `settings` was non-optional, so a server that stopped
  sending it would fail the whole status decode and silently freeze pairing state.
- Built the Live Activity spike around a standalone SQLite presentation record,
  with no event/source identity or time window. Native diagnostics creates the
  record and starts locally; edits and ending use ActivityKit APNs. This keeps UX
  exploration independent of event selection and lifecycle policy. Desired state,
  device observations, and push acceptance remain separate so diagnostics do not
  imply delivery. Attention is also explicit: ordinary updates remain quiet while an
  alerting update persists its intent across retries and asks iOS to briefly expand
  the Dynamic Island. Implementation: `Shared/ClarkLiveActivityAttributes.swift` and
  parent `lib/liveActivityStore.ts`; deployment status in
  [live-activity-spike.md](live-activity-spike.md).

## 2026-09-18

- Made sources first-class browser resources: every `/sources` route now swaps the
  device story gallery for an alphabetized source gallery, preserves the active
  source across tabs, and uses `/sources/:id` as a default-settings Feed preview.
  Source tabs no longer repeat selected-source identity, while Overview owns the
  complete registry metadata. This gives source inspection the same compact,
  persistent context as device administration (`plusjade/app-clarkview`,
  main snapshot 370; `render/pageShell.ts`, `render/sourceHtml.tsx`).

- Migrated `plusjade/feed-rams` from request-time Sleeper fan-out to the template's
  stored-upstream model. A six-hour UTC interval now fetches sixteen Eastern slate
  dates, atomically replaces a strict val-scoped Rams snapshot, and records coverage
  and last success; GET performs no upstream calls or writes. Failed refreshes leave
  the last good snapshot intact, moving third-party latency and availability out of
  the widget path while bounding schedule staleness (feed main snapshot 4;
  `rams.ts`, `refresh.ts`, `source.json`).

- Added a closed `source.json` manifest to the greenfield template and made its
  HTTP response import the declared key. Parent publication now validates manifest
  v1 and maps its key, name, and description deterministically instead of inferring
  identity from prose, val names, sampled output, or operator input. Semantic
  selection changes require a new key and row; deployment and operational changes
  retain identity. This keeps runtime and registry identity aligned while leaving
  instance ownership and trust with the parent (template snapshot 8; parent main
  snapshot 369; `docs/get-sources.md`).

- Required greenfield source remixes to classify their data lifecycle as computed,
  static, stored upstream, or live upstream. Mutable external data now defaults to
  interval ingestion plus source-owned SQLite, while live reads require an explicit
  freshness rationale, bounded fan-out/timeouts, and failure policy. The template
  also makes its no-settings personalization model and undefined `timeZone` semantics
  explicit. This preserves source-level design freedom while forcing widget-path
  reliability, staleness, and upstream load to be deliberate; black-box conformance
  does not establish those properties (template snapshot 7; `docs/valtown-brief.md`).

- Simplified greenfield GET context to `timeZone` alone, removing the redundant
  offset and its precedence question. It remains an optional no-op placeholder.
  iOS still sends `tz` to the parent for legacy sources; the greenfield verifier
  rejects offsets (`source/README.md`, template `main.ts`).

- Added optional `timeZone` context from iOS through the parent to greenfield GET
  sources and the remixable template. It is transport-only, preserving the viewer's
  named zone without deciding recurrence, conversion, fallback, or offset precedence.
  Legacy sources and stored reminder context are unchanged. The public verifier now
  covers the new argument (`source/README.md`, `Shared/ServerURL.swift`).

## 2026-09-17

- Refined the template after its first independent use: pass validated offsets into
  `readItems`, preserve absent versus explicit UTC, and make fallback choice and
  README ownership explicit. Verification now uses noninteractive inputs. This
  keeps common date-based sources inside the starter's intended edit points without
  imposing a timezone policy or changing the wire contract (template snapshot 4;
  parent documentation snapshot 358).

- Established `plusjade/source-template` as the greenfield authoring path: a small
  remix with no centralized runtime import, plus a parent-hosted black-box GET
  verifier. The parent owns the `get-no-settings` registry profile, wiring, and
  activation; sources need no parent access or legacy compatibility routes.
  This makes behavioral conformance the authoring boundary without migrating existing
  sources (parent main snapshot 357; `source/README.md`, `docs/get-sources.md`).

- Opted GTB instance 9 into the canonical GET feed, the first live source on the
  new transport. GTB's root directly validates the optional offset and temporal
  output while retaining v1 routes for browser/conformance compatibility. Shared
  storage selection preserves existing reminder semantics without a data migration
  (source main snapshot 15; parent `lib/sourceClient.ts`, main snapshot 356).

- Before any source opted into the greenfield read path, replaced the temporary
  `/v2/items` namespace and versioned response with the canonical source-val
  baseline: `GET /` returns `{sourceKey,items}`. A source val has one purpose, so
  the root is its feed; incompatible future versions may define a header or query
  parameter for explicit pinning when one actually exists. The parent section is
  now `source/`, and the hard-coded canonical opt-in set remains empty (parent main
  snapshot 355).

- Established a greenfield `GET /v2/items` source-read contract in
  `plusjade/app-clarkview`, alongside the existing POST v1 transport. The v2 query
  vocabulary intentionally matches the parent's narrow settings UI—booleans,
  repeated enumerated strings, and an optional timezone offset—so sources must
  simplify rather than grow an arbitrary JSON query language. Both transports now
  feed the live composer through one selection seam, but the hard-coded v2 source-ID
  set is empty, preserving all current device behavior. The contract is being grown
  under the parent for later extraction into a remixable source-template val rather
  than extending the standalone `source-sdk` import model (parent main snapshot
  353; superseded before adoption by the canonical baseline above).

- Migrated `plusjade/source-lunar` from SDK snapshot 3 and a bare `timestamp` to
  snapshot 17 with a source-owned one-hour `startsAt`/`expiresAt` window. Replaced
  its JSON payload table with a strict, normalized project database and atomic yearly
  rebuilds; the freely regenerable data was dropped and rebuilt for 2026–2027. The
  parent now rejects timestamp-only source items, retaining `timestamp` duplication
  solely at the iOS compatibility seam (Lunar main snapshot 12; parent snapshot 352).

- Removed source bearer authentication for the prototype: all active source HTTP
  operations are intentionally public, including writes and diagnostics, while
  source registration and assignment remain parent-owned. This removes duplicate
  credential provisioning and prevents the parent from holding a source credential
  that also authorizes writes. The parent no longer sends bearer headers, and the
  registry no longer stores `credential_ref`; current ownership and risk are recorded
  in [valtown-brief.md](valtown-brief.md).

- Moved source trust from an imported SDK to external conformance verification, and gated
  device feeds on it. Every source imported `source-sdk` at a pinned revision, so trust was
  a claim about a dependency rather than about behavior — and nothing forced re-checking, so
  Lunar sat on `@3-main` publishing a wrong-looking noon anchor for an unknown period while
  every check stayed green. The parent now probes each registered endpoint through its own
  request-path guards (`normalizeItems`, `parseFormSchema`), so a source cannot be certified
  by one definition and served by another; `sources` carries `conformance_state` and its
  timestamps, and only a `verified` source reaches a resolver, a reminder, or the browser
  Feed. Assertions are invariants, not values, because a source is probed against live data
  whose emptiness is not its fault. The decay this targets is time, not pins: a schedule
  re-probes every source, and staleness is surfaced rather than enforced — gating on it
  would let an outage of the probe blank the fleet. Quarantine is reported in
  `x-quarantined-sources` because otherwise a withheld source and an unconfigured device
  produce the same successful empty response. All six sources verified at cutover, so no
  feed changed. Parent `docs/source-conformance.md` owns the contract.

- Replaced per-item `caption` with a global `lifecycle` label set owned by the parent.
  `caption` was a free-text string each source filled in, and it conflated two unrelated
  things: the phase word (`LIVE`/`END`, time-varying) and whether an item had a real clock
  time (static, per source). Its contract was "any string", so nothing tied it to lifecycle
  at all, and four sources carried byte-identical `captionFor` copies. Now a source
  publishes only a window; `phase()` gives the state and one label set in the parent's
  `lib/lifecycle.ts` gives the word. Swift resolves the phase against its own clock from a
  root-level `lifecycle` object, and the timeline carries an entry at every item bound, so
  a word can no longer be stale between refreshes. Additive on the wire: `caption` and
  `emphasized` still ship, derived from the same labels, for builds that predate it —
  `emphasized` was decoded but never rendered by any template, which is why the new
  contract drops it rather than implementing it. Per-source label sets were considered and
  deferred (YAGNI): they cost every source author a decision no source has yet needed.
  Parent snapshot 349, SDK snapshot 17, sources repinned; Lunar is the exception, still on
  SDK 3 — see the brief's gotchas for what that costs it.

- Reduced the parent's `tools/` from 18 scripts to a 10-check core run by
  `tools/check.ts`, plus two manual push diagnostics. The recurring token cost came
  from docs pointing at individual checks and a read-before-run rule, not from running
  them. Removed applied migrations, completed cutover checks, a fixture composing a
  retired source, and a check that depended on production rows. AGENTS.md "Tests"
  makes checks a black box; parent main snapshot 348.

## 2026-09-16

- Retired parent registry ID 3 and its obsolete astronomical-event source. The
  parent had no remaining device assignments or reminder rows for that ID, so the
  stale registry pointer and source-specific operational checks were removed rather
  than introducing a compatibility path. Generic one-second instantaneous-item
  coverage remains in the parent and Swift tests.

- Migrated `plusjade/source-cfb` from the inherited mixed-sport millisecond cache to
  a CFB-only `cfb_games` table with explicit `starts_at`/`expires_at` Unix-second
  windows. Sleeper's `start_time` is now converted only at the upstream adapter, so
  persistence, selection, diagnostics, and source-protocol output share one temporal
  model. Historical mixed-sport/cache data was intentionally removed because the
  source has no historical-data requirement.
- Added the active `weekly-refresh.ts` interval to refresh a rolling seven-day CFB
  window every week. Bounded fetch waves and per-request timeouts were retained after
  an initial manual run exceeded the Val Town gateway timeout; the subsequent run
  stored 75 valid events and the deployed contract and diagnostics checks passed.
- Migrated `plusjade/source-wnba` to the same explicit-window storage model in a
  WNBA-only `wnba_games` table. Nested Sleeper team values and millisecond starts are
  normalized only at ingestion, while selection, diagnostics, and protocol reads use
  stored Unix-second bounds. The legacy 30-row cache was intentionally discarded.
- Changed WNBA's existing hourly `refresh.ts` interval to a weekly seven-day refresh;
  bounded fetch waves and request timeouts keep the scheduled run finite. The initial
  sync stored 25 games with valid two-hour windows, and the deployed 50-assertion
  contract check and diagnostics check passed.

## 2026-09-15

- Added Live/Disabled assignment participation while retaining settings, renamed the
  aggregate view Feed, and added isolated saved-settings Source previews. Avoided
  staging because it implies draft configuration that a single settings object
  cannot provide. Both resolvers and reminders honor the live selection; queued
  reminders recheck participation before delivery. Parent
  `docs/source-participation.md` and `tools/source-state-check.ts` own the semantics
  and verification. Browser composition uses the device's last reported offset.

- Completed source `intradayFilter` retirement: removed schemas, parser fields,
  filtering branches and dead status normalization from NFL/CFB/WNBA/WFIBA; removed
  eight assignment keys and four schema snapshot properties while preserving device
  presentation. Unknown keys now fail outright. Removed the early-final override so
  captions and device visibility agree on the published window, accepting estimated
  expiry instead of fabricating an end timestamp. Source snapshots: NFL 18, CFB 15,
  WNBA 16, WFIBA 53; parent 345. Parent `tools/source-intraday-cutover-check.ts`
  verifies the live contract and `tools/remove-source-intraday.ts` owns the cleanup.

- Added device presentation `intradayFilter` at the parent's shared item composition
  seam (main snapshot 344). Expiry visibility is device policy over source-owned
  temporal windows, so one predicate now covers resolvers, preview, and reminders.
  Default remains off and the native wire is unchanged. Source-setting removal is
  a separate aggressive cutover with no adapter; parent `docs/intraday-filter.md`
  records the remaining early-final and stored-key cleanup requirements.

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
