# Clark View and Val Town: agent brief

Read this before using Val Town MCP tools or changing the iOS/server boundary.

**Maintenance rule — read before editing this file.** Update current ownership,
contracts, procedures, and constraints in their relevant sections; remove superseded
guidance. Keep the short rationale needed to explain a constraint's scope and failure
mode. Route decision history and consequential operational evidence using
[AGENTS.md](../AGENTS.md#documenting-decisions). Temporary observations need a scoped
status section with a date, evidence pointer, and recheck or closure condition;
removing a date does not make a claim durable. Preserve verification pointers when
trimming old results. Treat cached system facts as snapshots to verify when relevant
to the task, not as re-confirmed fact.

## Start here: ownership and request flow

Clark View is widget-first. The containing iOS app pairs an install and exposes
diagnostics/manual reload. A browser helper configures sources. The widget displays
server-composed temporal items.

```text
Browser → app-clarkview → bunches, devices, source registry, assignments
App     → app-clarkview /pair, /devices/status/:installId
Widget  → app-clarkview /config/resolve
                         → device assignments + source pointers
                         → authenticated HTTP reads of assigned source vals
                         → validate items, sort, attach presentation → widget v2
Source ingest → implementing source's /v1/write → that val's SQLite
app-clarkview → best-effort APNs → WidgetKit → normal resolver fetch
```

| Concern | Owner / first place to inspect |
| --- | --- |
| Layout, family limits, local date/time, empty state, interaction, reload scheduling | This repository: `ClarkViewWidget/` and `Shared/` |
| Enrollment, registry pointers, assignments, browser forms, composition, presentation configuration, push delivery | `plusjade/app-clarkview` (the parent) |
| Team vocabulary, selection, event/status/broadcast text, upstream normalization, storage, ingestion | The implementing `plusjade/source-*` val |
| Generic source protocol and item validation | `plusjade/source-sdk`, imported by every active source |
| Widget wire fields or their meaning | Coordinate source output, parent composition, Swift decoding, fixtures, and tests |

Do not put source-domain policy in Swift or source-specific dispatch in the parent's
generic settings/composition path. The parent understands temporal view items; it has
no internal games model. There is no intermediate feed val.

## Design intent

A source is an independently operated capability, not a table — the point is letting
agents produce feeds without deploying application code into the parent. The intended
lifecycle is sandboxed authoring → deterministic validation → immutable release →
pointer activation → contract-conforming serving; only pointer activation and serving
are implemented today (see "Deferred" below). Items, facets, and options are the
default data model; a custom implementation can expose the same contracts through a
separately authorized code deployment path.

The generic feed composer deliberately lives in the parent, next to pointer
resolution, rather than in its own composer val: parent → composer → source would add
a hop and distribute pointer/credential management before there's a need. Composition
is kept as a pure helper so it can move later if that changes.

## Stable deployment identities

The parent is `plusjade/app-clarkview`, branch `main`, public code/public app access.
Its HTTP entry is **`main.ts`**, file ID **`f0eeffb8-9a93-11f1-9bb6-1607ee4eb77e`**,
endpoint **`https://plusjade--f0eeffb89a9311f19bb61607ee4eb77e.web.val.run/`**.
[ServerURL.swift](../Shared/ServerURL.swift) owns the same iOS base URL.

**Preserve the HTTP file's identity: update it in place; do not delete, recreate, or
rename it.** Endpoint identity follows the file ID, not its name. When verification is
needed, use `links.endpoint` from `val_town_list_files`; do not invent URLs from val
names. Keep iOS on this endpoint — do not substitute an unverified alternate host.

All active sources are registered in bunch 1. IDs identify parent-owned instances, not
universal source kinds. Every source uses HTTP entry `rpc.ts` and application-level
bearer authentication despite public app access. Credential names are references only;
their values must never enter this repo.

| Instance ID | Val / source key | HTTP file ID | Endpoint | Credential |
| --- | --- | --- | --- | --- |
| 3 | `plusjade/source-moon` / `moon` | `2f093378-aaec-11f1-932c-1607ee4eb77e` | `https://plusjade--2f093378aaec11f1932c1607ee4eb77e.web.val.run` | `SOURCE_MOON_V1_TOKEN` |
| 4 | `plusjade/source-wfiba` / `wfiba` | `01a07d73-0d02-703f-be73-09449008031e` | `https://plusjade--01a07d730d02703fbe7309449008031e.web.val.run` | `SOURCE_WFIBA_V1_TOKEN` |
| 5 | `plusjade/source-nfl` / `nfl` | `01a07d9f-d1a7-75dc-86db-eb178f2b25b1` | `https://plusjade--01a07d9fd1a775dc86dbeb178f2b25b1.web.val.run` | `SOURCE_NFL_V1_TOKEN` |
| 6 | `plusjade/source-cfb` / `cfb` | `01a07dd8-7b2c-778e-9b98-1f67aa94b955` | `https://plusjade--01a07dd87b2c778e9b981f67aa94b955.web.val.run` | `SOURCE_CFB_V1_TOKEN` |
| 7 | `plusjade/source-wnba` / `wnba` | `01a07de5-f2ca-7358-a270-26c8bacce23f` | `https://plusjade--01a07de5f2ca7358a27026c8bacce23f.web.val.run` | `SOURCE_WNBA_V1_TOKEN` |

## Parent model and code map

Canonical parent tables are `bunches`, `bunch_codes`, `devices`, `sources`,
`device_sources`, `device_push_tokens`, and `notification_queue`. Sources own their data separately.

- `sources` is a bunch-owned instance registry: `id`, `bunch_id`, `name`, `endpoint`,
  `remote_source_key`, `contract_version`, `credential_ref`, plus descriptor/schema
  snapshots and timestamps. `kind` is unrestricted diagnostic metadata, neither unique
  nor the transport dispatch key. There is no separate definitions or
  `source_instances` table.
- A reinstall pairs into a new row; `/devices/:id/merge` resolves that by moving the
  live install ID onto the configured device and deleting the origin row. Adoption
  preserves the target's row ID, name, assignments, presentation and page; the retired
  install ID's push/alert token rows are dropped. Nothing copies assignments forward,
  so the bunch triggers never fire.
- `device_sources` stores instance IDs and JSON settings. Triggers reject cross-bunch
  assignments and moving an attached source. Moving a device into another bunch clears
  its previous assignments. A valid bunch code is the enrollment/move path; membership
  is not a full agent ACL system.
- The legacy `priority` column is inert. Composition orders by item start time, then
  source ID and source-local item ID. No current form sets priority.
- Source pointers are trusted parent configuration; device settings cannot override
  destinations. Item IDs become `<source-id>:<local-id>`, remaining stable across a
  compatible endpoint change.
- Assigned sources execute concurrently. A failed source fails the whole composition;
  partial-feed degradation is not implemented.
- **Absent, unknown, or unassigned devices receive an empty schema-v2 feed** with
  normal presentation and no source request. There is no starter feed.

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
shared `pageShell` styles, existing breadcrumbs/config navigation. React is not a
reason to add a component library or client-side JavaScript.

## HTTP contracts used by iOS and the browser

| Method / route | Behavior |
| --- | --- |
| `GET /config/resolve` | Widget entry: `device=<install UUID>`, `tz=<seconds east of GMT>`. Returns schema-v2 JSON directly, no redirect, `cache-control: no-store`. Swift still sends legacy `d=<pixels>x<pixels>`; the parent ignores it. |
| `GET /devices/resolve` | Alias using the same `composeDeviceFeed` path |
| `POST /pair` | App sends `{code,device}`. Success 200 `{ok:true,deviceId}`; unknown code 404; expired code 422. Swift requires only `ok`. Codes are six characters and reusable for 30 minutes. |
| `POST /devices/register` | Same enrollment with optional `name` |
| `GET /config/status/:deviceId` | Legacy diagnostics using the install UUID, not an integer row ID. Unknown install returns `{deviceId,paired:false}`. Registered response includes registration/name/source diagnostics; optional sports/teams projection is compatibility-only. |
| `GET /devices/status/:installId` | App registration/source diagnostics: `{deviceId,registered,name,sources:[{kind,settings}]}`; unknown install omits name/sources and returns `registered:false`. Kind is nonunique metadata; settings are source-owned JSON. |
| `POST /device/token` | `{device,token,kind:"widget",environment:"sandbox"\|"production",active}`; `active:false` removes the token. Legacy omitted fields support old app-background tokens. Registration may precede pairing. |
| `GET /` | Always HTML, including query-bearing URLs; links to `/bunches`, `/devices`, `/sources` |
| `/devices/:id` | Integer-ID browser resource, name edit, assignment and presentation subpages |
| `/devices/:id/sources/new`, `/devices/:id/sources`, `/devices/:id/sources/:assignmentId` | Choose an eligible instance, then add/edit descriptor-driven settings; deletion uses POST to the assignment's `/delete` route |
| `/devices/:id/presentation`, `/devices/:id/preview` | Edit device presentation; preview the same composition as the resolver |
| `/devices/:id/merge` | Move a reinstalled app's install ID onto the device it replaces; the chosen target survives and the origin row is deleted |
| `/sources`, `/sources/:id` | Read-only registry explorer; the resource redirects to `/sources/:id/overview` |
| `/sources/:id/overview`, `/sources/:id/diagnostics`, `/sources/:id/settings`, `/sources/:id/devices` | Standalone resource tabs for metadata, stored coverage, schema, and attached devices |
| `POST /internal/reminders/{build,drain}` | Reminder jobs behind `REMINDERS_TOKEN` bearer auth; unset returns 401. Drain accepts an optional row `id`, keeping an external scheduler swappable for the cron. |
| `/bunches`, `/bunches/new`, `/bunches/:id`, `/bunches/:id/pair`, `/bunches/:id/codes` | Enrollment administration and pairing-code creation |

Resolver diagnostics include `x-device-feed-provider: source-registry-v1`,
`x-effective-source-count`, and `x-effective-sources` (e.g. `3:moon,5:nfl`). Zero
assignments produce count `0` and an empty effective-sources header. **A successful
empty response alone does not prove an assigned source works** — check the headers.

## Two independent wire versions

**Source protocol v1** is the authenticated parent/source seam. **Widget schema v2**
is the parent/iOS display contract. Neither is an SDK deployment revision.

### Source protocol and SDK

| Operation | Envelope / rule |
| --- | --- |
| `GET /v1/descriptor?sourceKey=...` | Protocol/source identity, `temporal:true`, settings schema, supported capabilities |
| `POST /v1/read` | Request `{protocolVersion:1,sourceKey,settings,context:{utcOffsetSeconds:number\|null}}`; response `{protocolVersion:1,sourceKey,items}` |
| `POST /v1/validate-settings` | Request `{protocolVersion:1,sourceKey,settings}`; success `{protocolVersion:1,sourceKey,ok:true}` |
| `POST /v1/write` | Request `{protocolVersion:1,sourceKey,operation,payload}`; success `{protocolVersion:1,sourceKey,ok:true,result}` |
| `/v1/publish` | Unsupported: 501; descriptors advertise `publish:false` |

No install identity, pairing data, presentation, or widget dimensions go to a source.
`null` offset preserves its default timezone behavior. Every item is temporal and uses
the widget's literal item keys. Validate responses at the seam, including identity,
duplicate IDs, and a finite Unix-second window whose expiry is strictly after its
start and within a plausible span (the span rule is what catches a bound written in
milliseconds).

The shared SDK is `plusjade/source-sdk`, public and dependency-free, with no HTTP
entry, storage, credentials, or schedules. See its
[creator guide](https://www.val.town/x/plusjade/source-sdk/code/README.md). Every
active source must import its public entrypoint at a tested immutable pin:

```ts
import { accept, reject, defineSource, serveSource, type Item }
  from "https://esm.town/v/plusjade/source-sdk@12-main/mod.ts";
```

Use one revision throughout a source; update pins on a branch, run checks, then
merge.

Source implementation boundaries:

- SDK (`sdk/`, exported by `mod.ts`): domain-free types, definition, protocol serving
  and guards. Must not depend on host-val code. Capabilities derive from implemented
  writes; dispatch accepts own properties only.
- `moonSource.ts`, `wfibaSource.ts`, `nflSource.ts`, etc.: definition, settings policy
  and write operations. `parseSettings` may read storage and pass resolved context to
  `read`; keep it free of mutation and avoid reading the catalog twice.
- Source `lib/`: domain adapters, selection, persistence and item text.
- `rpc.ts`: source-owned bearer authentication and HTTP mounts.

**Gotcha:** SQLite scope follows the executing val, not the imported module's owner.
Calling a database-backed source function by importing it into the parent would access
the parent's database — cross-val data work must go over HTTP instead. The SDK
executes inside its importing source without another HTTP hop. Provision source
schema at deployment, not during feed reads. A Val Town code branch does not isolate
SQLite, and a remix's copied database does not stay in sync — inspect copied
entrypoints and environment metadata when remixing.

### Generic settings forms

Supported fields are booleans and arrays of string choices in a closed object; choices
use `const`, `title`, optional `x-group`. The live authenticated descriptor, not a
stored schema snapshot, drives editing. No parent branch should depend on a source
kind or a field named `teams`. Full vocabulary and save semantics:
[source-settings-contract.md](source-settings-contract.md).

### Widget payload

```json
{
  "schemaVersion": 3,
  "items": [{
    "id": "5:example-event",
    "mainText": "Away @ Home",
    "subText": "Network · availability",
    "caption": null,
    "emphasized": false,
    "startsAt": 1788044400,
    "expiresAt": 1788055200,
    "timestamp": 1788044400
  }],
  "presentation": {
    "version": 2,
    "template": "beacon",
    "rootSurface": { "light": "#FFFFFF", "dark": "#000000" }
  }
}
```

- Source-owned text and emphasis are display decisions, not raw sports data. The
  parent sorts; Swift renders array order without sorting. No scores/live clock.
- **An item is a window, not an instant.** `startsAt` and `expiresAt` are Unix
  **seconds**, both required, `expiresAt` strictly greater; Swift decodes them with
  `.secondsSince1970`. Never send milliseconds or shift the instant by the client's
  offset. Swift derives the local day label from `startsAt` and, when `caption` is
  null, the local clock time.
- **`expiresAt` is an estimate and is never displayed**, on any surface. A source
  publishes a typical duration, so a long event reads as expired while still running;
  that is the accepted cost of deriving lifecycle from the clock instead of an ingest.
  The client uses it for *timing* — `nextRefreshDate(for:after:)` schedules the
  timeline reload on the next bound — never for *wording*.
- An instantaneous event (Moon's peak) publishes a **one-second window**, never a null
  bound: a nullable expiry classifies as already-expired under `now > null` in JS and
  vanishes from `expires_at > :now` in SQL, both silently.
- Schema 3 added the window. `timestamp` still ships as a duplicate of `startsAt` for
  builds that predate it, and Swift falls back to it; drop both once those builds are
  gone. A source still publishing only `timestamp` is upgraded by the parent to a
  one-second window rather than rejected — neither parent nor client may invent a
  duration.
- Sports use `LIVE` with emphasis and `END` without it, chosen by the source from the
  item's phase. Moon uses `PEAK` to avoid implying the astronomical instant is local
  moonrise or a viewing recommendation. The protocol's phase vocabulary
  (`upcoming | current | expired`) is state, never display text.
- Parent adds `presentation` from the device, defaulting to Beacon with white/black
  roots. It also emits deprecated `eyebrow:"NEXT"`; Swift ignores unknown keys.
- Presentation version 2 selects a whole widget-family template, not dimensions. Root
  colors are opaque `#RRGGBB`. Malformed/missing presentation, unknown versions or
  templates (including retired `system-v1` and `standard-v1`) fall back without losing
  valid items. Invalid individual root colors fall back independently.
- Preserve fields compatibly. Removal or repurposing requires coordinated schema
  versioning, Swift model/decoder, parent/source, preview fixture and test changes.

## iOS implementation and refresh behavior

| Local file | Role |
| --- | --- |
| [ServerURL.swift](../Shared/ServerURL.swift) | Base URL and resolver query |
| [WidgetPayload.swift](../Shared/WidgetPayload.swift), [WidgetPresentation.swift](../Shared/WidgetPresentation.swift) | Wire decoding and presentation fallback |
| [ClarkViewWidget.swift](../ClarkViewWidget/ClarkViewWidget.swift) | Fetch/cache, preview fixtures, hourly timeline, entry view |
| [BeaconWidgetTemplate.swift](../ClarkViewWidget/BeaconWidgetTemplate.swift), [BeaconWidgetFocusLayouts.swift](../ClarkViewWidget/BeaconWidgetFocusLayouts.swift) | Default layout and focus transition |
| [WidgetFocusStore.swift](../Shared/WidgetFocusStore.swift), [FocusWidgetItemIntent.swift](../ClarkViewWidget/FocusWidgetItemIntent.swift) | Shared local focus and short interaction-cache window |
| [DeviceIdentity.swift](../Shared/DeviceIdentity.swift) | Per-install UUID in `group.plusjade.clark-view`; local paired flag is copy-only |
| [PairingClient.swift](../Shared/PairingClient.swift), [DeviceStatusClient.swift](../Shared/DeviceStatusClient.swift) | Enrollment and diagnostic reads |
| [PushTokenClient.swift](../Shared/PushTokenClient.swift), [ClarkViewWidgetPushHandler.swift](../ClarkViewWidget/ClarkViewWidgetPushHandler.swift) | Native widget token upload/removal |
| [WidgetRefreshDiagnostics.swift](../Shared/WidgetRefreshDiagnostics.swift), [ContentView.swift](../clark_view/ContentView.swift) | Last manual request, network attempt, success/failure and app reload controls |

Beacon small/medium show the first item; large shows the first two. Local focus
expands either item in place without reordering server items (`StaticConfiguration`
means focus is shared across instances) and uses a 15-second cache-reuse window on the
last decoded App Group payload; explicit refresh clears that window. Ordinary
network/decoding failure currently returns an empty payload, not stale cached content
— distinguish failed fetches from successful empty feeds in diagnostics. Beacon has no
refresh button; manual refresh lives in the app only. Reload requests ask WidgetKit
for a timeline and do not guarantee immediate execution; the normal timeline requests
an hourly refresh. Native accented/vibrant appearances remain system-owned; Beacon respects
Reduce Motion and Reduce Transparency. Consult Swift for geometry, not this brief.

The widget extension owns its push entitlement and `.pushHandler`. The containing app
separately requests visible-notification permission, registers an app token, and
uploads it with the last observed alert permission to
`/device/notifications/register`. See [push-notifications.md](push-notifications.md)
for setup, the token/topic contract, and current verification status — don't restate
those facts here.

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

**Parent timestamp convention: ISO-8601 UTC text matching `Date.toISOString()`.** Every
stored time now follows it, `device_alert_tokens.last_test_at` included (a never-tested
registration is NULL, not a sentinel). `lib/time.ts` owns the format, `NOW_UTC`, and the
conversion helpers; write stored times through it and never `datetime()` or `unixepoch()`.
The format is fixed-width, so string comparison is chronological comparison and SQL
compares times without conversion. The `T` separator is load-bearing: SQLite's
`datetime()` emits a space and `'T'` sorts above `' '`, so a mixed column orders wrongly
and silently — and because SQLite coerces a number written to a TEXT column, an
epoch-integer write lands as a string sorting below every real date. Retyping a column
requires rebuilding the table; both migrations are idempotent and detect the old type.
Item bounds on the source protocol and widget wire remain Unix seconds. That wire
contract is where the epoch habit came from; converting at the storage boundary keeps the
contract from dictating the schema.

## Source operations and freshness

Reads use stored data; refreshing a widget does not ingest upstream events. No
automatic ingestion schedules are configured for these sources.

**Lifecycle no longer waits on ingest.** Each source derives its caption from
`phase(item, now)` over the item's own window at read time, so a game that kicked off
five minutes ago reads `LIVE` with no ingest in between. A stored `final` status still
wins over the estimated expiry — knowing an event ended beats estimating that it did —
but a stale `scheduled` no longer freezes the display. The same phase drives each
source's `intradayFilter` ("hide a game as soon as it ends"), so the filter and the
caption can no longer disagree. Default durations are source-owned named constants
(`NFL_TYPICAL_GAME_SECONDS` and siblings); neither the SDK nor the parent may supply
one.

All five active sources expose authenticated `GET /diagnostics`. Each source's
`diagnostics.ts` maps its own storage to
`{diagnosticsVersion:1,sourceKey,scope:"stored",totalItems,earliestTimestamp,latestTimestamp,lastIngestedAt}`.
Event bounds are Unix seconds; empty sources return zero and null bounds. The parent
validates this optional response in `lib/sourceDiagnostics.ts` and fetches it through
`lib/sourceDiagnosticsClient.ts` only on the Diagnostics tab. It never guesses source
tables or counts a filtered `/v1/read` response as total coverage. **Unsupported or
unavailable diagnostics mean unknown, not zero** — stored bounds never establish
complete coverage or current event statuses on their own.
See the parent's `docs/source-diagnostics.md`; verification entrypoints are the
parent's `tools/source-diagnostics-check.ts` and each source's `diagnostics-check.ts`.

| Source | Settings / storage | Write and known operational limits |
| --- | --- | --- |
| Moon | Exactly `{}`; `full_moons(date_key,payload,fetched_at)` | `cache.put` with `{source:"moon",dateKey,payload}`. Curated dataset with a finite horizon; seed the next year manually before it runs out. Payload has `peakTime`, `name`, `isBlueMoon`. |
| Women's FIBA | 16 stable nation slugs plus `intradayFilter`; indexed `wfiba_games`, independent roster in `wfiba_teams` | `games.ingest` with `{dateKey,payload}`. Each date replaces its rows authoritatively. Off-platform `tools/ingest.ts` fetches ESPN; `GET /coverage` diagnoses storage. |
| NFL | 32 team choices plus `intradayFilter`; indexed `cached_games` | `sleeper.refresh` with integer `{days:1..31}`; NFL-only normalization/storage |
| CFB | Curated `trojans`/`bruins` choices plus `intradayFilter`; indexed `cached_games` | Same refresh operation, CFB-only; not a full college roster |
| WNBA | 15 choices plus `intradayFilter`; indexed `cached_games` | Same refresh operation, WNBA-only; accepts Sleeper nested `{team:code}` and stored flat codes |

Sports sources use per-team next-game union/deduplication and client-day bounds.
Sleeper refresh uses Eastern-day windows, including yesterday for clients west of
Eastern. `tz` is offset **seconds**, not minutes or an IANA timezone name.

FIBA's ESPN scoreboard endpoint is
`site.api.espn.com/apis/site/v2/sports/basketball/fiba/scoreboard?dates=YYYYMMDD`.

**FIBA ingestion gotchas:**

- If Val Town egress to ESPN is blocked, fetch off-platform (a local script or a
  browser) and write directly to the source via `games.ingest`. See the scoped
  observation below before treating this workaround as necessary.
- Each `games.ingest` call for a date **replaces that date's rows authoritatively**.
  Do not rerun the ESPN ingest blindly over an already hand-verified date: an empty or
  incomplete payload erases what's stored — it does not merge.
- League 53 is a reused ESPN tournament bucket, not a permanent women's-FIBA feed —
  revalidate competition, gender, roster and date buckets before reusing it beyond the
  tournament it was set up for.
- ESPN's coverage can end before a tournament does. When it does, the official FIBA
  tournament schedule site is a working fallback for manual capture — its text
  extraction can omit fixtures hidden behind date controls, so drive it with a browser
  instead, and cross-check displayed times against the site's explicit GMT times (the
  page itself renders client-local). Never infer participants or assign a concrete
  time to a TBD pairing; retain provenance for anything captured this way.

### Operational observation: ESPN egress

The pre-cleanup brief recorded HTTP 403 from Val Town to the ESPN endpoint, including
with a browser User-Agent, last checked 2026-09-07. Evidence pointer:
`git show eb93ce0^:docs/valtown-brief.md`, "Source operations and freshness".
This observation was recovered from documentation history, not re-tested here. When
changing the ingestion path or diagnosing access, recheck with a read-only request
from the intended runtime; update or close this observation if access changes. The
stored-data replacement constraint above still applies regardless of fetch location.

## Verification loops

Classify the change using the ownership map above before touching anything remote.
Local layout work needs no remote calls; source work needs the source's own README;
protocol/authoring work needs the SDK guide.

Remote workflow: start from the cached identities in this file (use
`val_town_get_val_detail` only if branch/ownership/access is actually in question);
list files once at the needed directory, then read only the implicated modules. Use
targeted `val_town_replace_in_file`, or `val_town_update_file` for a mostly-rewritten
file; keep route wiring in `main.ts`. For multi-file/contract work, use one branch per
affected val, verify, then merge once per val. Verify representative deployed HTTP
with `val_town_fetch_val_endpoint` against `main.ts` (parent) or `rpc.ts` (source) and
the intended pathname/search — **a root-page fetch does not substitute for testing the
actual changed route.**

Inspect checks before running them: some create fixtures, and code branches share
SQLite. Locate parent settings/boundary checks under `tools/` when needed.

Per domain, what to run and what a false pass looks like:

| Domain | Run | False pass to watch for |
| --- | --- | --- |
| Composition | Both resolver aliases and the browser preview; empty/unassigned and assigned mixed-source fixtures; namespaced IDs, ordering, ties, diagnostics, source failure, malformed output | A successful *empty* response doesn't prove an assigned source actually works — check `x-effective-sources` |
| Source | Authenticated descriptor/read, auth rejection, settings/write guards, nonempty fixtures, timezone edges, source-specific selection. Moon's `check.ts`, other sources' `tools/source-contract-check.ts`, shared SDK `tools/sdk-check.ts` | Diagnostics reporting "unavailable" means unknown coverage, not zero |
| Settings | Add/edit/clear round trips, removed choices, stale fingerprint, invalid/unavailable source responses, no persistence on failure | — |
| Widget contract | Decode a representative composed response with Swift; update preview fixtures/tests; build app and widget for contract changes (`xcodebuild -project clark_view.xcodeproj -scheme clark_view build`/`test`); run SwiftLint | — |
| Push | Verify token environment/topic and actual delivery separately per environment | APNs *accepting* a request is not proof a banner appeared — use console delivery logs; a simulator build proves nothing about real APNs delivery |
| Reminders | `tools/reminder-check.ts`: due predicate, single-claim delivery, cancellation, lateness guards, disabled dry run; disposable fixtures, no APNs requests | A disabled run exercises queue processing without proving APNs delivery; the builder still writes live queue state |
| Browser | `/` and any query-bearing root must remain HTML | — |

Do not use production writes as casual smoke tests. Enrollment, assignments, names,
tokens, ingest and schema operations mutate state — use scoped disposable fixtures and
clean them up, accounting for shared SQLite even on branches. Prefer read-only route
diagnostics, then narrow, parameterized `val_town_sqlite_execute` queries with
`mode:"read"` and the exact owning val database. Do not put install IDs, capability
IDs, pairing codes, APNs tokens or secret values into chat, logs, fixtures or this
repository.

For a blank/stale widget, trace in order: app refresh diagnostics → resolver
status/body and effective sources → assignments/settings → source read/coverage →
ingestion. A push/reload cannot repair an empty assignment or a stale source cache.

## Gotchas and deliberately unfinished work

Keep these constraints; use Git/Val Town history for change lists and old probes.

- **No shared catalog table.** An earlier shared per-competition catalog design
  (`catalog_competitions`/`catalog_teams`) was replaced by each source owning its own
  team list — do not reintroduce a shared catalog table. No NBA replacement exists.
  The parent has no `/ingest/:source/:dateKey`, `/moon`, `/messages`, or root JSON/PNG
  representation.
- **Compare absolute instants at timezone boundaries.** A retired Sports FIBA
  implementation scanned UTC buckets using a client-local date floor, dropping valid
  games at UTC+14. Women's FIBA queries absolute instants and has a regression check.
  Moon retains its own date-selection semantics; a timezone redesign requires
  source-specific fixtures, not a blanket shift of timestamps.
- **Do not replay completed token backfills.** `INSERT OR IGNORE` only skips rows
  still present, so replaying a backfill after a dead-token cleanup can resurrect
  retired tokens. `tools/device-token-check.ts` guards schema initialization and
  widget token preference; preserve that behavior when changing token persistence.
- **Remixes can retain credentials.** Unused inherited keys can remain in a remixed
  val; there is no delete-env operation in the current MCP tooling. Do not assume
  cleanup of copied secrets happened, or bundle it into an unrelated change.
- **Deferred:** immutable source publication/activation, agent ACLs, advanced
  sharing/subscriptions, partial-feed degradation, automated ingestion, and next-year
  Moon seeding, per-source reminder leads, reminder quiet hours (requires an IANA
  timezone from the app), and widget refresh alongside reminder alerts. Implement
  these only when the task actually calls for them.
