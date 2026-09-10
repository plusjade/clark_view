# Clark View and Val Town: agent brief

Read this before using Val Town MCP tools or changing the iOS/server boundary.

**Maintenance rule — read before editing this file.** This is a map of the current
state of the system, not a deployment log. If a sentence you're about to add contains
a date, an actor ("the operator reported…", "the user confirmed…"), or an event
count, it doesn't belong here — see AGENTS.md's documentation-routing rule: the *why*
goes in [`docs/CHANGELOG.md`](CHANGELOG.md), and only the durable, dateless rule or
gotcha (if any) stays in this file. Update a section in place rather than layering a
new revision note on top of an old one. Treat everything below as a snapshot to
verify when it's actually relevant to the task, not as re-confirmed fact.

## Start here: ownership and request flow

Clark View is widget-first. The containing iOS app pairs an install and exposes
diagnostics/manual reload. A browser helper configures sources. The widget displays
server-composed temporal items.

```text
Browser → sports-today → bunches, devices, source registry, assignments
App     → sports-today /pair, /devices/status/:installId
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

The parent is `plusjade/sports-today`, branch `main`, public code/public app access.
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
- The legacy `priority` column is inert. Composition orders by timestamp, then source
  ID and source-local item ID. No current form sets priority.
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
| `/bunches`, `/bunches/new`, `/bunches/:id`, `/bunches/:id/pair`, `/bunches/:id/codes` | Enrollment administration and pairing-code creation |
| `POST /internal/reminders/{build,drain}` | Reminder jobs behind `REMINDERS_TOKEN` bearer auth; unset returns 401. Drain accepts an optional row `id`, keeping an external scheduler swappable for the cron. |

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
duplicate IDs and finite Unix-second timestamps.

The shared SDK is `plusjade/source-sdk`, public and dependency-free, with no HTTP
entry, storage, credentials, or schedules. See its
[creator guide](https://www.val.town/x/plusjade/source-sdk/code/README.md). Moon and
Women's FIBA import its public entrypoint at a tested immutable pin:

```ts
import { accept, reject, defineSource, serveSource, type Item }
  from "https://esm.town/v/plusjade/source-sdk@3-main/mod.ts";
```

NFL, CFB and WNBA still vendor their SDK — do not assume editing the shared val
updates them. Use one revision throughout a source; update pins on a branch, run
checks, then merge.

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

- Source-owned text and emphasis are display decisions, not raw sports data. The
  parent sorts; Swift renders array order without sorting. No scores/live clock.
- `timestamp` is Unix **seconds**, decoded with `.secondsSince1970`. Never send
  milliseconds or shift the instant by the client's offset. Swift derives the local
  day label and, when `caption` is null, the local clock time.
- Sports use `LIVE` with emphasis and `END` without it. Moon uses `PEAK` to avoid
  implying the astronomical instant is local moonrise or a viewing recommendation.
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
