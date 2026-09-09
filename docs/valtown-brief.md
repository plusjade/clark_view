# Clark View and Val Town: agent brief

Read this before using Val Town MCP tools or changing the iOS/server boundary.
This is a working map of the system, not a deployment log. Server facts below
are consolidated from deployment records through **2026-09-08**; this editorial
revision checked local Swift but did not re-query production. Treat coverage,
credentials, assignments, and deployment revisions as snapshots to verify only
when relevant to the task.

## Start here: ownership and request flow

Clark View is widget-first. The containing iOS app pairs an install and exposes
diagnostics/manual reload. A helper configures its sources in the browser.
The widget displays server-composed temporal items.

```text
Browser → sports-today → bunches, devices, source registry, assignments
App     → sports-today /pair, /config/status/:deviceId
Widget  → sports-today /config/resolve
                         → device assignments + source pointers
                         → authenticated HTTP reads of assigned source vals
                         → validate items, sort, attach presentation → widget v2
Source ingest → implementing source's /v1/write → that val's SQLite
sports-today → best-effort APNs → WidgetKit → normal resolver fetch
```

| Concern | Owner / first place to inspect |
| --- | --- |
| Layout, family limits, local date/time, empty state, interaction, reload scheduling | This repository: `ClarkViewWidget/` and `Shared/` |
| Enrollment, registry pointers, assignments, browser forms, composition, presentation configuration, push delivery | `plusjade/sports-today` (the parent) |
| Team vocabulary, selection, event/status/broadcast text, upstream normalization, storage, ingestion | The implementing `plusjade/source-*` val |
| Generic source protocol and item validation | `plusjade/source-sdk`; some sources still vendor the SDK |
| Widget wire fields or their meaning | Coordinate source output, parent composition, Swift decoding, fixtures, and tests |

Do not put source-domain policy in Swift or source-specific dispatch in the
parent's generic settings/composition path. The parent understands temporal
view items; it has no internal games model. There is no intermediate feed val.

## Stable deployment identities

The parent is `plusjade/sports-today`, branch `main`, public code/public app
access. Its HTTP entry is **`main.ts`**, file ID
**`f0eeffb8-9a93-11f1-9bb6-1607ee4eb77e`**, endpoint
**`https://plusjade--f0eeffb89a9311f19bb61607ee4eb77e.web.val.run/`**.
[GameDataURL.swift](../Shared/GameDataURL.swift) owns the same iOS base URL.

**Preserve the HTTP file's identity: update it in place; do not delete, recreate,
or rename it.** Endpoint identity follows the file ID, not its name. When
verification is needed, use `links.endpoint` from `val_town_list_files`; do not
invent URLs from val names. Keep iOS on this endpoint: `jade.beer` was previously
stale for status/token routes and is not a verified replacement.

All active sources below were registered in bunch 1. IDs identify parent-owned
instances, not universal source kinds. Every source uses HTTP entry `rpc.ts`
and application-level bearer authentication despite public app access.
Credential names are references only; their values must never enter this repo.

| Instance ID | Val / source key | HTTP file ID | Credential in parent and source |
| --- | --- | --- | --- |
| 3 | `plusjade/source-moon` / `moon` | `2f093378-aaec-11f1-932c-1607ee4eb77e` | `SOURCE_MOON_V1_TOKEN` |
| 4 | `plusjade/source-wfiba` / `wfiba` | `01a07d73-0d02-703f-be73-09449008031e` | `SOURCE_WFIBA_V1_TOKEN` |
| 5 | `plusjade/source-nfl` / `nfl` | `01a07d9f-d1a7-75dc-86db-eb178f2b25b1` | `SOURCE_NFL_V1_TOKEN` |
| 6 | `plusjade/source-cfb` / `cfb` | `01a07dd8-7b2c-778e-9b98-1f67aa94b955` | `SOURCE_CFB_V1_TOKEN` |
| 7 | `plusjade/source-wnba` / `wnba` | `01a07de5-f2ca-7358-a270-26c8bacce23f` | `SOURCE_WNBA_V1_TOKEN` |

Cached endpoints, in the same order:

- Moon: `https://plusjade--2f093378aaec11f1932c1607ee4eb77e.web.val.run`
- Women's FIBA: `https://plusjade--01a07d730d02703fbe7309449008031e.web.val.run`
- NFL: `https://plusjade--01a07d9fd1a775dc86dbeb178f2b25b1.web.val.run`
- CFB: `https://plusjade--01a07dd87b2c778e9b981f67aa94b955.web.val.run`
- WNBA: `https://plusjade--01a07de5f2ca7358a27026c8bacce23f.web.val.run`

## Parent model and code map

Canonical parent tables are `bunches`, `bunch_codes`, `devices`, `sources`,
`device_sources`, `device_push_tokens`, and `notification_queue`. Sources own their data separately.

- `sources` is a bunch-owned instance registry: `id`, `bunch_id`, `name`,
  `endpoint`, `remote_source_key`, `contract_version`, `credential_ref`, plus
  descriptor/schema snapshots and timestamps. `kind` is unrestricted diagnostic
  metadata, neither unique nor the transport dispatch key. There is no separate
  definitions or `source_instances` table.
- A reinstall pairs into a new row; `/devices/:id/merge` resolves that by moving
  the live install ID onto the configured device and deleting the origin row.
  Adoption preserves the target's row ID, name, assignments, presentation and
  page; the retired install ID's push/alert token rows are dropped. Nothing
  copies assignments forward, so the bunch triggers never fire.
- `device_sources` stores instance IDs and JSON settings. Triggers reject
  cross-bunch assignments and moving an attached source. Moving a device into
  another bunch clears its previous assignments. A valid bunch code is the
  enrollment/move path; membership is not a full agent ACL system.
- The legacy `priority` column is inert. Composition orders by timestamp, then
  source ID and source-local item ID. No current form sets priority.
- Source pointers are trusted parent configuration; device settings cannot
  override destinations. Item IDs become `<source-id>:<local-id>`, remaining
  stable across a compatible endpoint change.
- Assigned sources execute concurrently. A failed source fails the whole
  composition; partial-feed degradation is not implemented.
- **Absent, unknown, or unassigned devices receive an empty schema-v2 feed**
  with normal presentation and no source request. There is no starter feed.

| Parent path | Responsibility |
| --- | --- |
| `main.ts`, `http/routes/*.ts` | Stable Hono wiring, iOS routes, browser administration; no parent ingest route |
| `lib/sourceClient.ts` | Source lookup/transport, protocol/item guards, shared selection/query types, `composeDeviceFeed` |
| `lib/sourceSettings.ts` | Live descriptor validation, form decoding, source validation before persistence |
| `lib/sourceStore.ts` | Registry and browser source projections |
| `lib/deviceStore.ts`, `lib/deviceSourceStore.ts` | Device/assignment writes and widget-facing configuration lookup |
| `lib/bunchStore.ts` | Bunch administration, reusable 30-minute codes, registration |
| `lib/presentation.ts` | Presentation defaults, stored JSON parsing, form validation |
| `lib/deviceTokenStore.ts`, `lib/push.ts` | Token lifecycle and best-effort device notification (`notifyDevice`) |
| `lib/reminderStore.ts` | `notification_queue` ledger, device reminder columns, claim and settlement |
| `lib/reminderBuilder.ts`, `lib/reminderDrainer.ts` | Queue events from composed feeds; send due reminders as alerts |
| `crons/buildReminders.ts`, `crons/drainReminders.ts` | The two reminder schedules |
| `lib/guards.ts` | Domain-free runtime guards |
| `render/pageShell.ts` | Browser styles, semantic hierarchy, navigation and shared form/table rules |
| `render/deviceHtml.tsx`, `render/sourceHtml.tsx`, `render/bunchHtml.tsx` | Device settings/preview, source explorer, enrollment views |
| `render/rootHtml.ts`, `render/dataTable.tsx` | HTML root and shared tables |

Browser work follows `AGENTS.md`: native semantic HTML, compact data-dense views,
shared `pageShell` styles, existing breadcrumbs/config navigation. React is not
a reason to add a component library or client-side JavaScript.

## HTTP contracts used by iOS and the browser

| Method / route | Behavior |
| --- | --- |
| `GET /config/resolve` | Widget entry: `device=<install UUID>`, `tz=<seconds east of GMT>`. Returns schema-v2 JSON directly, no redirect, `cache-control: no-store`. Swift still sends legacy `d=<pixels>x<pixels>`; the parent ignores it. |
| `GET /devices/resolve` | Alias using the same `composeDeviceFeed` path |
| `POST /pair` | App sends `{code,device}`. Success 200 `{ok:true,deviceId}`; unknown code 404; expired code 422. Swift requires only `ok`. Codes are six characters and reusable for 30 minutes. |
| `POST /devices/register` | Same enrollment with optional `name` |
| `GET /config/status/:deviceId` | App diagnostics using the install UUID, not an integer row ID. Unknown install returns `{deviceId,paired:false}`. Registered response includes registration/name/source diagnostics; optional sports/teams projection is compatibility-only. |
| `GET /devices/status/:installId` | New-model registration/source-settings diagnostics |
| `POST /device/token` | `{device,token,kind:"widget",environment:"sandbox"\|"production",active}`; `active:false` removes the token. Legacy omitted fields support old app-background tokens. Registration may precede pairing. |
| `GET /` | Always HTML, including query-bearing URLs; links to `/bunches`, `/devices`, `/sources` |
| `/devices/:id` | Integer-ID browser resource, name edit, assignment and presentation subpages |
| `/devices/:id/sources/new`, `/devices/:id/sources`, `/devices/:id/sources/:assignmentId` | Choose an eligible instance, then add/edit descriptor-driven settings; deletion uses POST to the assignment's `/delete` route |
| `/devices/:id/presentation`, `/devices/:id/preview` | Edit device presentation; preview the same composition as the resolver |
| `/devices/:id/merge` | Move a reinstalled app's install ID onto the device it replaces; the chosen target survives and the origin row is deleted |
| `/sources`, `/sources/:id` | Read-only registry explorer, implementing endpoint, schema, attached devices |
| `/bunches`, `/bunches/new`, `/bunches/:id`, `/bunches/:id/pair`, `/bunches/:id/codes` | Enrollment administration and pairing-code creation |
| `POST /internal/reminders/{build,drain}` | Reminder jobs behind `REMINDERS_TOKEN` bearer auth; unset returns 401. Drain accepts an optional row `id`, keeping an external scheduler swappable for the cron. |

Resolver diagnostics include `x-device-feed-provider: source-registry-v1`,
`x-effective-source-count`, and `x-effective-sources` (e.g. `3:moon,5:nfl`).
Zero assignments produce count `0` and an empty effective-sources header.
A successful empty response alone does not prove an assigned source works.

## Two independent wire versions

**Source protocol v1** is the authenticated parent/source seam. **Widget schema
v2** is the parent/iOS display contract. Neither is an SDK deployment revision.

### Source protocol and SDK

| Operation | Envelope / rule |
| --- | --- |
| `GET /v1/descriptor?sourceKey=...` | Protocol/source identity, `temporal:true`, settings schema, supported capabilities |
| `POST /v1/read` | Request `{protocolVersion:1,sourceKey,settings,context:{utcOffsetSeconds:number\|null}}`; response `{protocolVersion:1,sourceKey,items}` |
| `POST /v1/validate-settings` | Request `{protocolVersion:1,sourceKey,settings}`; success `{protocolVersion:1,sourceKey,ok:true}` |
| `POST /v1/write` | Request `{protocolVersion:1,sourceKey,operation,payload}`; success `{protocolVersion:1,sourceKey,ok:true,result}` |
| `/v1/publish` | Unsupported: 501; descriptors advertise `publish:false` |

No install identity, pairing data, presentation, or widget dimensions go to a
source. `null` offset preserves its default timezone behavior. Every item is
temporal and uses the widget's literal item keys. Validate responses at the seam,
including identity, duplicate IDs and finite Unix-second timestamps.

The shared SDK is `plusjade/source-sdk`, public and dependency-free, with no
HTTP entry, storage, credentials, or schedules. See its
[creator guide](https://www.val.town/x/plusjade/source-sdk/code/README.md).
Moon and Women's FIBA import its public entrypoint at this tested immutable pin:

```ts
import { accept, reject, defineSource, serveSource, type Item }
  from "https://esm.town/v/plusjade/source-sdk@3-main/mod.ts";
```

NFL, CFB and WNBA still vendor their SDK. Do not assume editing the shared val
updates them, or that later SDK documentation revisions changed deployed code.
Use one revision throughout a source; update pins on a branch, run checks, then
merge. Full source releases/pointer activation remain mutable prototype behavior;
an immutable SDK import does not make the whole source an immutable release.

Source implementation boundaries:

- SDK (`sdk/`, exported by `mod.ts`): domain-free types, definition, protocol
  serving and guards. It must not depend on host-val code. Capabilities derive
  from implemented writes; dispatch accepts own properties only.
- `moonSource.ts`, `wfibaSource.ts`, `nflSource.ts`, etc.: definition, settings
  policy and write operations. `parseSettings` may read storage and pass resolved
  context to `read`; keep it free of mutation and avoid reading the catalog twice.
- Source `lib/`: domain adapters, selection, persistence and item text.
- `rpc.ts`: source-owned bearer authentication and HTTP mounts.

**SQLite scope follows the executing val**, not the imported module's owner.
Calling a database-backed source function by importing it into the parent would
access the parent's database. Cross-val data work must enter the source over
HTTP. The SDK executes inside its importing source without another HTTP hop.
Provision source schema at deployment, not during feed reads. Do not assume a
Val Town code branch isolates SQLite or that a remix's copied database stays in
sync; inspect copied entrypoints and environment metadata when remixing.

### Generic settings forms

The detailed vocabulary and save semantics live in
[source-settings-contract.md](source-settings-contract.md). The **live
authenticated descriptor**, not the registry schema snapshot, drives editing.
Supported fields are booleans and arrays of string choices in a closed object;
choices use `const`, `title`, optional `x-group`. Moon's `{}` schema has no controls.
No parent branch should depend on a source kind or a field named `teams`.

The parent reloads the descriptor on save and checks the form fingerprint (409
if stale), decodes submitted fields, then calls source validation. Invalid values
return 422; unavailable/unsupported descriptors or validation return 502. Failures
do not change assignments. Clearing saves false/[] rather than defaults; removed
choices remain visible until explicitly removed. Reads still validate settings.

### Widget payload

```json
{
  "schemaVersion": 2,
  "items": [{
    "id": "5:example-event",
    "mainText": "Away @ Home",
    "subText": "Network · availability",
    "caption": null,
    "emphasized": false,
    "timestamp": 1788044400
  }],
  "presentation": {
    "version": 2,
    "template": "beacon",
    "rootSurface": { "light": "#FFFFFF", "dark": "#000000" }
  }
}
```

- Source-owned text and emphasis are display decisions, not raw sports data.
  The parent sorts; Swift renders array order without sorting. No scores/live clock.
- `timestamp` is Unix **seconds**, decoded with `.secondsSince1970`. Never send
  milliseconds or shift the instant by the client's offset. Swift derives the
  local day label and, when `caption` is null, the local clock time.
- Sports use `LIVE` with emphasis and `END` without it. Moon uses `PEAK` to avoid
  implying the astronomical instant is local moonrise or a viewing recommendation.
- Parent adds `presentation` from the device, defaulting to Beacon with white/black
  roots. It also emits deprecated `eyebrow:"NEXT"`; Swift ignores unknown keys.
- Presentation version 2 selects a whole widget-family template, not dimensions.
  Root colors are opaque `#RRGGBB`. Malformed/missing presentation, unknown versions
  or templates (including retired `system-v1`) fall back without losing valid items.
  Invalid individual root colors fall back independently. `standard-v1` remains
  supported in Swift but deprecated and unavailable in the browser editor.
- Preserve fields compatibly. Removal or repurposing requires coordinated schema
  versioning, Swift model/decoder, parent/source, preview fixture and test changes.

## iOS implementation and refresh behavior

| Local file | Role |
| --- | --- |
| [GameDataURL.swift](../Shared/GameDataURL.swift) | Base URL and resolver query; its old redirect comment is stale |
| [WidgetPayload.swift](../Shared/WidgetPayload.swift), [WidgetPresentation.swift](../Shared/WidgetPresentation.swift) | Wire decoding and presentation fallback |
| [ClarkViewWidget.swift](../ClarkViewWidget/ClarkViewWidget.swift) | Fetch/cache, preview fixtures, hourly timeline, template dispatch, legacy layout |
| [BeaconWidgetTemplate.swift](../ClarkViewWidget/BeaconWidgetTemplate.swift), [BeaconWidgetFocusLayouts.swift](../ClarkViewWidget/BeaconWidgetFocusLayouts.swift) | Default layout and focus transition |
| [WidgetFocusStore.swift](../Shared/WidgetFocusStore.swift), [FocusWidgetItemIntent.swift](../ClarkViewWidget/FocusWidgetItemIntent.swift) | Shared local focus and short interaction-cache window |
| [DeviceIdentity.swift](../Shared/DeviceIdentity.swift) | Per-install UUID in `group.plusjade.clark-view`; local paired flag is copy-only |
| [PairingClient.swift](../Shared/PairingClient.swift), [DeviceStatusClient.swift](../Shared/DeviceStatusClient.swift) | Enrollment and diagnostic reads |
| [PushTokenClient.swift](../Shared/PushTokenClient.swift), [ClarkViewWidgetPushHandler.swift](../ClarkViewWidget/ClarkViewWidgetPushHandler.swift) | Native widget token upload/removal |
| [WidgetRefreshDiagnostics.swift](../Shared/WidgetRefreshDiagnostics.swift), [ContentView.swift](../clark_view/ContentView.swift) | Last manual request, network attempt, success/failure and app reload controls |

Beacon small/medium show the first item; large shows the first two. Local focus
expands either item in place without reordering server items. `StaticConfiguration`
means focus is shared across instances. Focus uses a 15-second cache-reuse window
for the last decoded App Group payload; explicit refresh clears that window.
Ordinary network/decoding failure currently returns an empty payload, not stale
cached content. Distinguish failed fetches from successful empty feeds in diagnostics.

Beacon has no refresh button; manual refresh lives in the app. The deprecated
standard template retains one. Reload requests ask WidgetKit for a timeline and
do not guarantee immediate execution. The normal timeline requests an hourly
refresh. Native accented/vibrant appearances remain system-owned; Beacon respects
Reduce Motion and Reduce Transparency. Consult Swift for geometry, not this brief.

The widget extension owns its push entitlement and `.pushHandler`. The containing
app separately requests visible-notification permission and registers an app token
and uploads it with the last observed alert permission to `/device/notifications/register`.
`/device/notifications/test` sends fixed self-test text with token proof and a cooldown.
`device_alert_tokens` is keyed by install/environment, independent of widget tokens. See
[push-notifications.md](push-notifications.md) for setup and remaining integration.
Parent APNs
uses push type `widgets`, containing-app topic `plusjade.clark-view.push-type.widgets`, and
`{"aps":{"content-changed":true}}`. Embedded signing profiles determine the environment; App Store builds without
profiles use production, and simulators use sandbox. Server delivery prefers widget tokens with a legacy app-background
fallback. The widget must be added before testing; pairing alone does not register its token.
Use the containing app bundle ID for the widget APNs topic, not the extension ID.
Push is opportunistic; it neither refreshes source data nor replaces
the hourly timeline.

APNs requires `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_AUTH_KEY`; `APNS_APP_TOPIC` and
`APNS_WIDGET_TOPIC` are optional overrides. The configured key is production-only.
Sandbox uses separate `APNS_SANDBOX_KEY_ID`/`APNS_SANDBOX_AUTH_KEY` credentials,
never production fallback. Both environments use the live val database. Missing
configuration skips delivery and the alert test returns an explicit reason.
All three credentials were configured on 2026-09-08. Running
`tools/apns-credentials-check.ts` confirmed identifier format, P-256 private-key
import, and signing in the server runtime without printing secrets. Sandbox
alert delivery was confirmed by the user. A sandbox widget push accepted at
20:50:27 UTC on 2026-09-08 produced matching Last Attempt/Last Success timestamps
on the phone, without a manual reload or visible notification permission.
Production authentication and delivery were subsequently verified end to end. Token
storage is independent of pairing, not tied to retired configs.

Event reminders run in the parent: `crons/buildReminders.ts` queues one
`notification_queue` row per upcoming feed item per device, and
`crons/drainReminders.ts` sends each row as a visible alert once `send_after` passes.
Alert channel only; a reminder does not refresh the widget. `UNIQUE(device_id,item_id,rule)`
plus a compare-and-swap claim make delivery at-most-once under overlapping runs and
repeated triggers, so an abandoned claim is failed rather than retried. `REMINDERS_ENABLED`
gates sending: while unset the queue still drains and records what each row would have
sent, which is the intended dry-run posture before enabling. The correctness constraint
is coverage, not latency — every device must be built at least once inside its own
reminder lead, so watch the oldest `devices.reminders_built_at` as the fleet grows.
`devices.last_tz_offset_seconds` is captured from the resolver's `tz`, conditionally and
best-effort; it is an offset, not a timezone, so quiet hours need an IANA identifier from
the app before they can be correct. Details in the parent's `docs/event-reminders.md`.

## Source operations and freshness

Reads use stored data; refreshing a widget does not ingest upstream events.
No automatic ingestion schedules were recorded for these sources.

| Source | Settings / storage | Write and known operational limits |
| --- | --- | --- |
| Moon | Exactly `{}`; `full_moons(date_key,payload,fetched_at)` | `cache.put` with `{source:"moon",dateKey,payload}`. Curated 13-event 2026 dataset ends Dec 24; seed the next year manually before exhaustion. Payload has `peakTime`, `name`, `isBlueMoon`. |
| Women's FIBA | 16 stable nation slugs plus `intradayFilter`; indexed `wfiba_games`, independent roster in `wfiba_teams` | `games.ingest` with `{dateKey,payload}`. Each date replaces its rows authoritatively. Off-platform `tools/ingest.ts` fetches ESPN; `GET /coverage` diagnoses storage. |
| NFL | 32 team choices plus `intradayFilter`; indexed `cached_games` | `sleeper.refresh` with integer `{days:1..31}`; NFL-only normalization/storage |
| CFB | Curated `trojans`/`bruins` choices plus `intradayFilter`; indexed `cached_games` | Same refresh operation, CFB-only; not a full college roster |
| WNBA | 15 choices plus `intradayFilter`; indexed `cached_games` | Same refresh operation, WNBA-only; accepts Sleeper nested `{team:code}` and stored flat codes |

Sports sources use per-team next-game union/deduplication and client-day bounds.
Sleeper refresh uses Eastern-day windows, including yesterday for clients west
of Eastern. `tz` is offset **seconds**, not minutes or an IANA timezone name.

FIBA's ESPN scoreboard endpoint is
`site.api.espn.com/apis/site/v2/sports/basketball/fiba/scoreboard?dates=YYYYMMDD`.
Val Town egress received 403, including with a browser User-Agent (last checked
2026-09-07); fetch off-platform and write directly to the source. League 53 is a
reused tournament bucket, not a permanent women's feed. Revalidate competition,
gender, roster and date buckets before using it beyond the 2026 tournament.
The UTC date filter assumes events belong to the requested bucket; the ingest
runner reports off-bucket events. Status stays frozen until another ingest.

Last recorded FIBA coverage (2026-09-07) was 24 group-stage games with Sep 8–14
empty pending bracket publication. WNBA refresh returned zero games for Sep 6–14.
These are observations, not current guarantees or proof of correct nonempty
upstream handling. Inspect coverage and representative stored/provider data for
freshness tasks; avoid silently adding a provider or schedule.

## Bounded remote workflow and verification

1. Classify the change using the ownership map. Local layout work needs no remote
   calls. Read the relevant source's README for source work; use the SDK guide
   for protocol/authoring work.
2. Start with cached identities. Use `val_town_get_val_detail` only if branch,
   ownership or access matters. List files once at the needed directory, then
   read exact implicated modules; avoid recursive inventories and repeated reads.
3. Use targeted `val_town_replace_in_file`; use `val_town_update_file` for a mostly
   rewritten file. Keep route wiring in `main.ts`. For multi-file/contract work,
   use one branch per affected val, verify, then merge once per val.
4. Test the changed path on the branch. Where supported, an edit's
   `run.kind: fetch_val_endpoint` can target the HTTP entry in the same call.
   A root-page fetch does not substitute for testing the actual changed route.
5. Verify representative deployed HTTP through `val_town_fetch_val_endpoint`
   using `main.ts` (parent) or `rpc.ts` (source) and the intended pathname/search.
   Check endpoint identity after deployment only if the entrypoint was touched
   or identity needs certification. Use filtered traces/logs after surprises.

Tests should prove the boundary being changed:

- Composition: both resolver aliases and browser preview; empty/unassigned and
  assigned mixed-source fixtures; namespaced IDs, chronological ordering and
  deterministic ties, diagnostics, source failure and malformed output.
- Source: authenticated descriptor/read, auth rejection, settings/write guards,
  meaningful nonempty fixtures, timezone edges, and source-specific selection.
  Relevant suites are Moon `check.ts`, other sources' `tools/source-contract-check.ts`,
  and shared SDK `tools/sdk-check.ts` (vendored SDK checks remain in unmigrated vals).
- Settings: add/edit/clear round trips, removed choices, stale fingerprint,
  invalid/unavailable source responses and no persistence on failure. Locate the
  parent settings/boundary checks under `tools/` when needed; their exact filenames
  are not cached here. Inspect checks before running them: they may create fixtures.
- Widget contract: decode a representative composed response with Swift and
  update preview fixtures/tests. Build app and widget for contract changes.
  Use `xcodebuild -project clark_view.xcodeproj -scheme clark_view build` and
  the corresponding `test` command with an available destination as needed.
  Unit tests use Swift Testing; UI tests use XCTest. Run SwiftLint for Swift edits.
- Reminders: `tools/reminder-check.ts` covers the due predicate, single-claim
  delivery, cancellation, lateness guards and the disabled dry run with disposable
  fixtures and no APNs requests. Running `crons/buildReminders.ts` directly is a safe
  live rehearsal while `REMINDERS_ENABLED` is unset.
- Browser root: `/` and a query-bearing root must remain HTML. Native push:
  separately verify token environment/topic and actual delivery; an HTTP feed
  success or simulator build does not establish APNs delivery.

Do not use production writes as casual smoke tests. Enrollment, assignments,
names, tokens, ingest and schema operations mutate state. For required write
validation, use scoped disposable fixtures and clean them up; account for shared
SQLite even on branches. Prefer read-only route diagnostics, then narrow,
parameterized `val_town_sqlite_execute` queries with `mode:"read"` and the exact
owning val database. Do not dump install IDs, capability IDs, pairing codes,
APNs tokens or secret values into chat, logs, fixtures or this repository.
Environment-key metadata is useful only when configuration is implicated.

For a blank/stale widget, trace in order: app refresh diagnostics → resolver
status/body and effective sources → assignments/settings → source read/coverage
→ ingestion. A push/reload cannot repair an empty assignment or stale source cache.

## Historical lessons and deliberately unfinished work

Keep these constraints; use Git/Val Town history for change lists and old probes.

- **Retired paths are not fallback options.** `sports-today-device-feed` has no
  HTTP/interval/email entrypoints and is not a supported rollback target.
  `source-sports` is retained but unregistered (row 1 removed); Messages row 2
  is retired. No NBA replacement exists. The parent has no `/ingest/:source/:dateKey`,
  `/moon`, `/messages`, or root JSON/PNG representation. Do not restore a hidden
  Sports fallback or edit the old sibling for active feed behavior.
- **Old topology prose can mislead.** [val-based-sources-plan.md](val-based-sources-plan.md)
  records design intent and migration steps; [catalog-model.md](catalog-model.md)
  describes the earlier multi-competition catalog. Neither overrides the current
  ownership map. `lib/deviceFeedClient.ts`, parent `lib/catalog.ts`, and parent
  `lib/resolver.ts` were removed. Swift's Games-oriented names/comments do not
  imply a current server Games model or a resolver redirect.
- **Compare absolute instants at timezone boundaries.** Retired Sports FIBA
  scanned UTC buckets using a client-local date floor, dropping valid games at
  UTC+14. Women's FIBA queries absolute instants and has a regression check.
  Moon retains its own existing date-selection semantics; a timezone redesign
  requires source-specific fixtures, not a blanket shift of timestamps.
- **Do not replay completed token backfills.** The retired `device_tokens`
  backfill resurrected app-background tokens after dead-token cleanup because
  `INSERT OR IGNORE` only skips rows still present. The table and replay were
  removed; `tools/device-token-check.ts` guards schema initialization and widget
  token preference. Preserve that behavior when changing token persistence.
- **Snapshots are not live state.** Parent `sources_before_val_boundary` and
  `device_sources_before_val_boundary` are recovery data, not registries. Copied
  non-league data/schema remain dormant in remixed sources. Historical row counts
  or passing empty parity probes do not establish current coverage.
- **Remixes can retain credentials.** Unused inherited keys remain in some vals;
  recorded MCP tooling had no delete-env operation. NFL destructive copied-data
  cleanup was previously rejected by automatic approval review and did not run.
  Do not assume cleanup happened or bundle it into an unrelated change.
- **Deferred:** immutable source publication/activation, agent ACLs, advanced
  sharing/subscriptions, partial-feed degradation, automated ingestion,
  next-year Moon seeding, per-source reminder leads, reminder quiet hours (blocked on
  an IANA timezone from the app), and widget refresh alongside a reminder alert. Implement these only when the task calls for them.

When maintaining this brief, update the relevant section in place. Keep endpoint
identities, ownership, contracts, verification entrypoints and actionable gotchas.
Date time-sensitive observations. Remove superseded guidance rather than layering
another override above it; omit per-task branch names, file-deletion inventories,
assertion counts and routine validation narratives.
