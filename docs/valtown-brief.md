# Clark View and Val Town: agent brief

Read this before using Val Town MCP tools or changing the iOS/server boundary.
Tool names below are unprefixed; the runtime prefix depends on how the Val Town MCP
is installed, so discover the live names from the tool listing.

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

Clark View is widget-first. The containing iOS app pairs an install, previews its
independently selected feed, and exposes notification setup and diagnostics through
its menu. A browser helper configures sources. Each widget explicitly selects a
server-composed temporal feed in its native editor.

```text
Browser → app-clarkview → feeds, devices, bunches, source registry
App     → app-clarkview /feeds, /feeds/:feedId; /pair and status remain installation routes
Widget  → app-clarkview /feeds/:feedId
                         → feed assignments + source pointers
                         → public HTTP reads of assigned source vals
                         → validate items, sort, attach presentation → widget v2
Source ingest → that source's own schedule → its own SQLite
app-clarkview → best-effort APNs → WidgetKit → normal resolver fetch
```

| Concern | Owner / first place to inspect |
| --- | --- |
| Layout, family limits, local date/time, empty state, interaction, reload scheduling | This repository: `ClarkViewWidget/` and `Shared/`; [ios-widget.md](ios-widget.md) |
| Enrollment, registry pointers, assignments, browser forms, composition, presentation configuration, push delivery | `plusjade/app-clarkview` (the parent) |
| Team vocabulary, selection, event/status/broadcast text, upstream normalization, storage, ingestion | The implementing `plusjade/source-*` val |
| New source authoring | Remix `plusjade/source-template`; update its canonical `source.json`, then follow `AGENTS.md` for implementation and external verification |
| Source contract and item validation | Parent `source/README.md`, `source/readContract.ts`, `lib/sourceContract.ts` and `lib/canonicalSource.ts` |
| Whether a source is trusted to serve, and why | Parent `lib/sourceConformance.ts` and `docs/source-conformance.md` |
| Widget wire fields or their meaning | Coordinate source output, parent composition, Swift decoding, fixtures, and tests |

Do not put source-domain policy in Swift or source-specific dispatch in the parent's
generic composition path. The parent understands temporal view items; it has
no internal games model. There is no intermediate feed val.

Classify the task before reading anything else. Each route is a budget, not a minimum:

| Task | Read | Do not load |
| --- | --- | --- |
| Widget layout, diagnostics, focus, deep links | [ios-widget.md](ios-widget.md) and the Swift it names | This file past the ownership map; any remote val |
| New source authoring | `plusjade/source-template`'s `AGENTS.md`, then its README | Parent implementation; sibling sources |
| Source behavior, storage, or ingestion | That source's own README and `AGENTS.md` | Parent modules; sibling sources |
| Parent routes, composition, browser, wire contracts | The code map below, then only the implicated parent modules | Swift; unrelated parent directories; other vals |

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
needed, use `links.endpoint` from `list_files`; do not invent URLs from val
names. Keep iOS on this endpoint — do not substitute an unverified alternate host.

All active sources are registered in bunch 1. IDs identify parent-owned instances, not
universal source kinds. Every source uses the public HTTP entry point defined by the val. During this
prototype stage, all source operations are intentionally unauthenticated, including
reads, diagnostics, ingest triggers, and other writes. Endpoint obscurity is not
authentication. Parent-owned registration and assignment remain parent-owned operations.

**Registration is not trust.** Each row also carries live conformance metadata —
`conformance_state`, `conformance_checked_at`, `conformance_verified_at`,
`conformance_detail` — written only by the parent's probe, and **only a `verified`
source reaches a composed feed or a reminder**. Those values change on every probe, so
read them from `/sources` (Verification column) or a source's Overview tab rather than
caching them here.

## Parent model and code map

Canonical parent tables include `bunches`, `bunch_codes`, `devices`, `sources`,
`feeds`, `feeds_sources`, `device_subscriptions`, `device_push_tokens`,
`subscription_notification_queue`, `device_widget_inventory`, and `device_feed_requests`. The retired `notification_queue` is retained
as delivery history.
`feeds` has independently allocated stable IDs, editable nonunique names,
presentation, and timestamps. `feeds_sources` has a unique feed/source pair,
foreign keys, and a Live/Disabled flag. Neither table has device ownership,
surface type, or ACL. Sources own their data separately.

- `sources` is a bunch-owned instance registry: `id`, `bunch_id`, `name`, `endpoint`,
  `remote_source_key`, `contract_version`, `read_profile`, plus timestamps. `read_transport`
  and `settings_schema` are inert leftovers of the retired protocol. `kind` is unrestricted diagnostic metadata, neither unique
  nor the transport dispatch key. There is no separate definitions or
  `source_instances` table.
- A reinstall pairs into a new device row; `/devices/:id/merge` moves its live
  install ID onto the target and deletes the origin. Feed IDs and content are untouched.
  The retired install ID's push/alert token rows are dropped.
- `feeds_sources` stores source instance IDs independently of bunch membership.
  Feed attachment does not require a device or matching bunch. The obsolete bunch
  triggers stay retired.
- Reminders require an explicit `device_subscriptions` row. Feed attachment,
  widget selection, and device enrollment never create one implicitly.
- The legacy `priority` column is inert. Composition orders by item start time, then
  source ID and source-local item ID. No current form sets priority.
- Feed assignment `enabled` is a non-null 0/1 flag. Live (1, default) contributes
  to public composition; Disabled (0) stays attached. An enabled unverified source
  is withheld and diagnosed. State controls work without source availability.
  Both legacy resolver aliases use a frozen installation-to-feed mapping.
- Source pointers are trusted parent configuration; nothing device-side can override
  destinations. Item IDs become `<source-id>:<local-id>`, remaining stable across a
  compatible endpoint change.
- Assigned sources execute concurrently. A failed source fails the whole composition;
  partial-feed degradation is not implemented.
- In the legacy resolver, absent, unknown, or unassigned devices receive an empty
  schema-3 feed with normal presentation and no source request. There is no starter feed.
- The one-time `independent-feeds-v1` migration copied every then-current device row,
  including empty rows, into `feeds` with the same ID, name, presentation, and
  timestamps. It copied all assignments including Disabled and froze installation
  mappings in `legacy_installation_feeds`. Later device creation creates no feed.
  Directory order is name (case-insensitive), then feed ID. A known empty feed succeeds;
  an unknown or deleted feed returns JSON 404.

| Parent path | Responsibility |
| --- | --- |
| `main.ts`, `http/routes/*.ts` | Stable Hono wiring, iOS routes, browser administration; no parent ingest route |
| `lib/sourceClient.ts` | Source lookup, canonical GET read, item guards, `composeFeed` |
| `lib/feedStore.ts` | Independent feed CRUD, source attachment, composition lookup, frozen legacy mapping |
| `lib/sourceStore.ts` | Registry and browser source projections |
| `lib/deviceStore.ts` | Device identity |
| `lib/bunchStore.ts` | Bunch administration, reusable 30-minute codes, registration |
| `lib/presentation.ts` | Presentation defaults, stored JSON parsing, form validation |
| `lib/deviceTokenStore.ts`, `lib/push.ts` | Token lifecycle and best-effort device notification (`notifyDevice`) |
| `lib/subscriptionStore.ts` | Explicit subscription policy and notification ledger |
| `lib/widgetObservationStore.ts`, `http/routes/widgetObservations.ts` | Device-reported widget inventory, feed-request receipts, `/devices/:id/views`; parent `docs/widget-inventory.md` |
| `lib/subscriptionBuilder.ts`, `lib/subscriptionDrainer.ts` | Queue events from subscribed feeds; validate and send due alerts |
| `crons/buildReminders.ts`, `crons/drainReminders.ts` | The two reminder schedules |
| `lib/lifecycle.ts` | Global lifecycle label set; phase-to-word resolution and the derived legacy caption |
| `lib/guards.ts` | Domain-free runtime guards |
| `render/pageShell.ts` | Browser styles, semantic hierarchy, navigation and shared form/table rules |
| `render/feedHtml.tsx`, `render/deviceHtml.tsx`, `render/sourceHtml.tsx`, `render/bunchHtml.tsx` | Feed administration, device identity and subscriptions, source explorer, enrollment |
| `render/rootHtml.ts`, `render/dataTable.tsx` | HTML root and shared tables |

Browser work follows `AGENTS.md`: native semantic HTML, compact data-dense views,
shared `pageShell` styles, existing breadcrumbs/config navigation. React is not a
reason to add a component library or client-side JavaScript.

The shared browser header links Home to `/` and displays an alphabetically ordered,
horizontally scrolling story-style gallery. `main.ts` fills `pageShell`'s single
gallery slot only in HTML responses; JSON routes do not load navigation data.
`/sources` and its subroutes show sources; feed management routes show feeds;
other browser routes show devices. Resource pages mark the current resource.
Browser tab titles retain resource names. The root remains a standalone jump-off screen.

## HTTP contracts used by iOS and the browser

| Method / route | Behavior |
| --- | --- |
| `GET /feeds` | Public, unpaired directory: `{feeds:[{id,name}]}`. IDs are decimal row IDs carried as opaque strings by Swift; no installation identity in the response. Read-only and `no-store`. |
| `GET /feeds/:feedId` | Public, unpaired schema-3 composition from an independent feed's enabled and verified assignments and presentation. Optional `timeZone` reader context. Unknown or deleted IDs return JSON 404; a valid empty feed succeeds. Reads use `no-store`. Optional `X-Clark-Installation`, `X-Clark-Caller`, `X-Clark-Widget-Family`, `X-Clark-Request-Purpose` headers record a receipt for a registered device only; they never change the response. |
| `POST /device/widget-inventory` | `{device,observedAt,widgets:[{kind,family,state,feedId?}]}` complete snapshot; `state` is `configured`/`unconfigured`/`unreadable`. Replaces the stored snapshot unless older (`{ok:true,stale:true}`). Unknown install 404, malformed 400. |
| `GET /installations/:installId/feed` | One-time native migration lookup through frozen `legacy_installation_feeds`, returning `{id,name}` or JSON 404. New installations have no mapping. |
| `GET /config/resolve` | Temporary legacy client feed through the frozen installation mapping: `device=<install UUID>`, `tz=<seconds east of GMT>`, optional `timeZone=<named zone>`. Unmapped requests return an empty schema-3 feed. Retain until client cutover is confirmed. |
| `GET /devices/resolve` | Temporary alias through the same frozen mapping |
| `POST /pair` | App sends `{code,device}`. Success 200 `{ok:true,deviceId}`; unknown code 404; expired code 422. Swift requires only `ok`. Codes are six characters and reusable for 30 minutes. |
| `POST /devices/register` | Same enrollment with optional `name` |
| `GET /config/status/:deviceId` | Legacy diagnostics using the install UUID. Unknown install returns `{deviceId,paired:false}`. Registered response carries name and compatibility-only empty `teams`. |
| `GET /devices/status/:installId` | App registration diagnostics: `{deviceId,registered,name}`; unknown install omits name and returns `registered:false`. |
| `POST /device/token` | `{device,token,kind:"widget",environment:"sandbox"\|"production",active}`; `active:false` removes the token. Legacy omitted fields support old app-background tokens. Registration may precede pairing. |
| `GET /` | HTML entry with links to `/bunches`, `/devices`, `/feeds/manage`, and `/sources` |
| `/feeds/manage`, `/feeds/new` | Browser feed index and creation; `/feeds` remains JSON |
| `/feeds/:id/manage` | Feed preview, source attachment/state/removal, presentation, rename, and deletion |
| `/devices/:id`, `/devices/:id/settings`, `/devices/:id/subscriptions` | Device identity and name edit, explicit feed subscriptions, enrollment and merge entry |
| `/devices/:id/views` | Latest reported widget inventory and per feed/caller/family/purpose request receipts, labeled with report times |
| `/devices/:id/merge` | Move a reinstalled app's install ID onto the device it replaces; the chosen target survives and the origin row is deleted |
| `/sources` | Read-only registry explorer with the source gallery in place of the device gallery |
| `/sources/:id` | Source Feed tab: reads the implementing source with its schema defaults and renders temporal items plus the raw source response; failures and empty feeds remain ordinary page states |
| `/sources/:id/overview`, `/sources/:id/diagnostics`, `/sources/:id/feeds` | Source tabs for registry metadata and verification, stored coverage, and attached feeds |
| `POST /internal/reminders/{build,drain}` | Subscription reminder jobs behind `REMINDERS_TOKEN` bearer auth; unset returns 401. Drain accepts an optional row `id`, keeping an external scheduler swappable for the cron. |
| `/bunches`, `/bunches/new`, `/bunches/:id`, `/bunches/:id/pair`, `/bunches/:id/codes` | Enrollment administration and pairing-code creation |

Resolver diagnostics include `x-device-feed-provider: source-registry-v1`,
`x-effective-source-count`, `x-effective-sources` (e.g. `5:nfl,6:cfb`), and
`x-quarantined-sources` (e.g. `8:failing`). Zero assignments produce count `0` and both
headers empty. **A successful empty response alone does not prove an assigned source
works** — check the headers. An enabled assignment withheld for non-conformance appears
only in `x-quarantined-sources`; without it, quarantine and an empty configuration are
the same response.

## Wire versions

The **canonical GET source feed** is the only parent/source seam. **Widget schema 3**
is the parent/iOS display contract.

### Canonical GET source feed

`lib/sourceClient.ts:readSourceItems` performs one GET of the source root and
validates the response through `lib/canonicalSource.ts`, the same guards the
conformance probe uses. `sources.read_profile` must be `get-no-settings`;
`sourcePointer` refuses any other value, because the column still defaults to the
retired `v1` and a row that never set it would otherwise reach a removed transport.
`read_transport` and `settings_schema` remain as inert columns — dropping them would
require rebuilding `sources` and cascading away every assignment.

The source-facing contract and its dependency-free path encoder live in the parent's
`source/README.md` and `source/readContract.ts`. **Sources take no settings.** The
request accepts one optional `timeZone` and nothing else; an unknown parameter, a
duplicate `timeZone`, or the retired `utcOffsetSeconds` must be rejected with 400. A
capability that would need selection is a separate source, not a setting. Successful
responses carry `{sourceKey,items}` and use the temporal item contract.

iOS reads `TimeZone.autoupdatingCurrent` when fetching a selected feed and sends only
its identifier. Legacy resolver clients may still send a `tz` offset, but the parent
does not persist or forward it to a source.
`timeZone` is a no-op placeholder: one optional value of 1–128 ASCII letters, digits,
or `_+./-`, passed unchanged to the source. No zone lookup, conversion, or
missing-zone policy is defined yet. The template ignores the argument. Named zones
are not persisted or supplied to reminder jobs.

A source val has one purpose, so its root is the feed and the baseline has no version
namespace in its URL or response. If an incompatible version is eventually needed,
that future contract may define a request header or query parameter for callers that
need to pin it; no unused negotiation mechanism is reserved now.

`plusjade/source-template` is a remixable val with one HTTP file, a canonical
`source.json`, a README, and surgical `AGENTS.md`. The closed manifest v1 declares
source key, display identity, selection summary, data mode, and freshness summary;
`main.ts` imports its key so runtime and publication identity cannot drift. It
imports no shared runtime and has no parent credentials or calls. Sources own their
code and data; authoring agents use the public contract and verifier without
inspecting parent implementation. Before implementation, its
instructions require classifying the feed as computed, static, stored upstream, or
live upstream and recording freshness, failure, refresh, bootstrap, and selection
policy in the source README. Mutable external data defaults to interval ingestion
and source-owned SQLite; a live upstream read is a documented exception with bounded
fan-out and timeouts. Computed and static sources need no database. Prefer a
capability-specific personalized identity, and stop rather than inventing settings or
`timeZone` semantics. The parent refuses request targets longer than 2048 characters.

`POST /source-verifications` accepts `{endpoint,sourceKey}` for a public Val Town
root and returns `{profile,pass,checks,failures}`. It stops at the first failing
request and neither reads nor writes the registry. Parent-owned probes use the same
GET checker and serving guards before recording conformance. Registration and
assignment remain separate, manual operator actions; parent `docs/get-sources.md`
owns the wiring procedure and requires writing `read_profile` explicitly. Publication
reads the final branch's manifest deterministically, verifies the deployed response
matches its key, and maps manifest identity into the registry; it never discovers
identity from the val name, README prose, a sampled response, or operator wording.

**Conformance is verified externally, not by what a source imports.** The probe
asserts invariants, never values — an empty or off-season feed is a pass. Parent
`docs/source-conformance.md` owns the contract, the registry columns, and the
fail-open-on-staleness decision.

No install identity, pairing data, presentation, settings, or widget dimensions go to
a source. Every item is temporal and uses the widget's literal item keys. Validate
responses at the seam, including identity, duplicate IDs, and a finite Unix-second
window whose expiry is strictly after its start and within a plausible span (the span
rule is what catches a bound written in milliseconds).

**Gotcha:** SQLite scope follows the executing val, not the imported module's owner.
Calling a database-backed source function by importing it into the parent would access
the parent's database — cross-val data work must go over HTTP instead. Provision source
schema at deployment, not during feed reads. A Val Town code branch does not isolate
SQLite, and a remix's copied database does not stay in sync — inspect copied
entrypoints and environment metadata when remixing.

### Widget payload

```json
{
  "schemaVersion": 3,
  "lifecycle": { "upcoming": null, "current": "LIVE", "expired": "END" },
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

- Source-owned text is a display decision, not raw sports data. The parent sorts;
  Swift renders array order without sorting. No scores/live clock.
- **Lifecycle wording is the parent's, global, and not per source.** `lifecycle` carries
  one label per phase for the whole feed; Swift resolves each item's phase against its own
  window and clock. A `null` label means the client formats `startsAt` as a local time.
  Parent `docs/item-lifecycle.md` owns semantics and the label set.
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
- An instantaneous event publishes a **one-second window**, never a null
  bound: a nullable expiry classifies as already-expired under `now > null` in JS and
  vanishes from `expires_at > :now` in SQL, both silently.
- Schema 3 added the window. `timestamp` still ships as a duplicate of `startsAt` for
  builds that predate it, and Swift falls back to it; drop both once those builds are
  gone. The parent adds that duplicate only at the iOS seam. A source publishing only
  `timestamp` is invalid; every source must own and publish both window bounds.
- **`caption` and `emphasized` are retired.** They still ship per item, derived by the
  parent from the same labels, so builds predating `lifecycle` keep rendering; values a
  source sends for either are discarded. Swift reads `caption` only when `lifecycle` is
  absent, and has never rendered `emphasized`. Drop both once those builds are gone.
  The protocol's phase vocabulary (`upcoming | current | expired`) is state, never
  display text.
- Parent adds `presentation` from the feed, defaulting to Beacon with white/black
  roots. It also emits deprecated `eyebrow:"NEXT"`; Swift ignores unknown keys.
- Feed presentation stores `intradayFilter` (default false), edited as **Hide
  expired items**. `composeFeedItems` applies `expiresAt > now` after validation
  and composition with one clock snapshot across sources. Public reads and preview
  use it. Legacy reminder composition temporarily reads the old device presentation.
  This server-only setting is omitted from the
  native presentation envelope; no Swift contract change is needed. Off retains
  all returned candidates, without changing source coverage or refilling selection.
  Parent `docs/intraday-filter.md` owns semantics and the completed source cutover.
- Presentation version 2 selects a whole widget-family template, not dimensions. Root
  colors are opaque `#RRGGBB`. Malformed/missing presentation, unknown versions or
  templates (including retired `system-v1` and `standard-v1`) fall back without losing
  valid items. Invalid individual root colors fall back independently.
- Preserve fields compatibly. Removal or repurposing requires coordinated schema
  versioning, Swift model/decoder, parent/source, preview fixture and test changes.

## Reminders and stored time

**Cutover status (observed 2026-09-24).** The implementation was merged from
`independent-feeds` into parent `main` version 387. The shared database copy is recorded by
`feed_migrations.independent-feeds-v1`; both-direction value comparisons matched
five copied feeds and seventeen assignments. Live `/feeds`, `/feeds/:id`, and
`/feeds/manage` respond, parent `tools/check.ts` passes on `main`, and a
disposable feed/device isolation fixture passed and was removed. One iPhone 17
simulator had an installed but unconfigured widget; the bounded UI attempt did not
reach its Feed picker. The installed selection/edit/refresh smoke test remains
pending. Recheck and close this status after one widget is configured with a
named feed, that feed is edited in the browser, and the refreshed widget shows
the edit without changing its stored ID.

Subscription code was merged from `codex-device-subscriptions` to parent `main`
version 390 on 2026-09-25. The old jobs were stopped, five pending legacy queue
rows were voided without sending, and `device_sources` plus the obsolete device
reminder columns were removed. The old `notification_queue` remains as history.
Both replacement schedules are active: builder at :00/:15/:30/:45 UTC and drainer
at :05/:20/:35/:50 UTC. Parent `tools/check.ts` and a disposable disabled-send
smoke passed after schema removal. Scheduled runs at 17:00 and 17:05 UTC on
2026-09-25 logged zero work and no failures because no subscriptions existed.
For current operation, check `read_interval_settings` and the two cron file logs;
the parent `docs/subscriptions.md` owns the reminder contract.

Subscriptions follow current enabled, verified `feeds_sources` and canonical source
items, independent of feed presentation and widget selection. The ledger deduplicates
overlapping feeds by device, namespaced item ID, and lead; terminal results are not
replayed. `REMINDERS_ENABLED` gates APNs delivery. Alerts do not refresh the widget.
No old assignment becomes a subscription automatically. Quiet hours require a
named-zone policy and storage before they can be correct. Details in the parent's
`docs/subscriptions.md` and `docs/event-reminders.md`.

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

Every source declares a data lifecycle. Computed and static feeds may answer directly.
For mutable external data, the default is scheduled ingestion into source-owned
storage followed by mutation-free stored reads, so device count and upstream health
do not enter the widget request path. A live upstream read is allowed only as an
explicitly documented exception with bounded fan-out, timeout, freshness rationale,
and failure behavior. A GET never provisions schema, writes storage, or turns a
widget refresh into ingestion.

**Lifecycle no longer waits on ingest, and no longer belongs to sources.** A source
publishes a window and nothing about lifecycle; `phase()` over that window decides the
state, and the parent's global label set decides the word. A game that kicked off five
minutes ago reads `LIVE` with no ingest in between. Stored status does not override the
published window: an early-finished game remains current until its estimated expiry.
Sources take no settings, so nothing device-side narrows a public feed; feed presentation
owns expiry filtering. See the parent's `docs/intraday-filter.md` for the contract.
Default durations are source-owned named constants (Lunar's one-hour event window and
siblings); the parent may not supply one.

A source may expose a public `GET /diagnostics` mapping its own storage to
`{diagnosticsVersion:1,sourceKey,scope:"stored",totalItems,earliestTimestamp,latestTimestamp,lastIngestedAt}`.
Event bounds are Unix seconds; empty sources return zero and null bounds. The parent
validates this optional response in `lib/sourceDiagnostics.ts` and fetches it through
`lib/sourceDiagnosticsClient.ts` only on the Diagnostics tab. It never guesses source
tables. **Unsupported or unavailable diagnostics mean unknown, not zero** — stored
bounds never establish complete coverage or current event statuses on their own.
See the parent's `docs/source-diagnostics.md`.

The registered sources are `plusjade/feed-lunar`, `feed-gtb`, `feed-rams`,
`feed-fever`, `feed-sparks`, `feed-trojans` and `feed-bruins`, all on the canonical
GET profile. Each one's storage, refresh schedule and failure policy live in its own
README; do not restate them here.

| Source | Storage | Known operational shape |
| --- | --- | --- |
| Lunar | None; computed UTC+8-anchored calendar | Each GET computes the next fifteenth with Meeus new-moon arithmetic and emits a fixed-UTC one-hour window |
| Rams | Strict `rams_games` snapshot plus singleton `rams_refresh_state` | Active six-hour UTC interval fetches sixteen Sleeper Eastern slate dates in two waves, then atomically replaces the snapshot; GET reads storage only and emits the next game with a three-hour window |

Sources fetching Sleeper convert its `start_time` milliseconds at their upstream
adapter and store the resulting `starts_at`/`expires_at` **seconds** as the source's
canonical event window; reads pass those bounds straight through rather than
reconstructing expiry in a view layer. Refreshes fetch date buckets in bounded waves
with per-request timeouts, so a slow upstream cannot hold an interval open
indefinitely. Sleeper's day windows are Eastern, so a source serving clients west of
Eastern includes the previous day.

## Verification loops

Classify with the routing table above before touching anything remote.

Remote workflow: start from the cached identities in this file (use
`get_val_detail` only if branch/ownership/access is actually in question);
list files once at the needed directory, then read only the implicated modules.
`read_file` has no offset or limit, so a read costs the whole file, and `list_files`
is per-directory. Let file and directory boundaries follow what changes together:
read cost breaks ties between defensible boundaries, it never justifies splitting a
cohesive module, and a wrong guess costs a full read. Pass `show_line_numbers: false`
unless you are about to cite a line or call `insert_at_line`, and load the route's
tools in one discovery call rather than one per tool. Use targeted `replace_in_file`,
or `update_file` for a mostly-rewritten file; keep route wiring in `main.ts`. For multi-file/contract work,
use one branch per affected val, verify, then merge once per val. Verify
representative deployed HTTP with `fetch_val_endpoint` against the val's HTTP entry
(`main.ts`, in the parent and in every source) and the intended pathname/search.
**A root-page fetch does not substitute for testing the actual changed route.**

Automated checks follow the test policy in [AGENTS.md](../AGENTS.md#tests): parent
changes run `tools/check.ts`; source changes run that source's own checks.

Per domain, what to verify beyond the checks and what a false pass looks like:

| Domain | Run | False pass to watch for |
| --- | --- | --- |
| Composition | Both resolver aliases and the browser preview; empty/unassigned and assigned mixed-source fixtures; namespaced IDs, ordering, ties, diagnostics, source failure, malformed output | A successful *empty* response doesn't prove an assigned source actually works — check `x-effective-sources`, then `x-quarantined-sources` |
| Conformance | The probe against every registered source, and that only a verified one reaches a feed. Core suite covers gating, staleness derivation and quarantine diagnostics | A green feed says nothing about a source nobody has re-probed — check `conformance_verified_at`, not just the state |
| Source | Public `GET /`, its 400/405 rejections, nonempty fixtures, timezone edges. Source-owned checks | Diagnostics reporting "unavailable" means unknown coverage, not zero |
| New GET source | External `/source-verifications` against the remix's own endpoint and key; parent changes run `tools/check.ts` | A pass does not register or activate a source, prove data accuracy, or establish nonempty coverage |
| Attachment | Add/remove/state round trips; an attach carrying settings must be refused and persist nothing | — |
| Widget contract | Decode a representative composed response with Swift; update preview fixtures/tests; build app and widget for contract changes (`xcodebuild -project clark_view.xcodeproj -scheme clark_view build`/`test`); run SwiftLint | — |
| Push | Verify token environment/topic and actual delivery separately per environment | APNs *accepting* a request is not proof a banner appeared — use console delivery logs; a simulator build proves nothing about real APNs delivery |
| Reminders | Core suite; a disabled drain for queue processing | A disabled run exercises queue processing without proving APNs delivery; the builder still writes live queue state |
| Browser | `/` and any query-bearing root must remain HTML | — |

Do not use production writes as casual smoke tests. Enrollment, assignments, names,
tokens, ingest and schema operations mutate state — use scoped disposable fixtures and
clean them up, accounting for shared SQLite even on branches. Prefer read-only route
diagnostics, then narrow, parameterized `sqlite_execute` queries with
`mode:"read"` and the exact owning val database. Do not put install IDs, capability
IDs, pairing codes, APNs tokens or secret values into chat, logs, fixtures or this
repository.

For a blank/stale widget, trace in order: app refresh diagnostics → resolver
status/body and effective sources → assignments → source read/coverage →
ingestion. A push/reload cannot repair an empty assignment or a stale source cache.

## Gotchas and deliberately unfinished work

Keep these constraints; use Git/Val Town history for change lists and old probes.

- **Compare absolute instants at timezone boundaries.** Scanning UTC buckets from a
  client-local date floor drops valid events at UTC+14.
  Each non-sports source retains its own date-selection semantics; a timezone redesign requires
  source-specific fixtures, not a blanket shift of timestamps.
- **Never rebuild `sources` to change a constraint.** Foreign keys are on and
  `feeds_sources` cascades on delete, so dropping the table wipes assignments.
  Add a column instead.
- **Do not replay completed token backfills.** `INSERT OR IGNORE` only skips rows
  still present, so replaying a backfill after a dead-token cleanup can resurrect
  retired tokens. Schema initialization must not recreate the retired `device_tokens`
  table, and lookup prefers a device's widget token; preserve both when changing token
  persistence.
- **Remixes can retain credentials.** Unused inherited keys can remain in a remixed
  val; there is no delete-env operation in the current MCP tooling. Do not assume
  cleanup of copied secrets happened, or bundle it into an unrelated change.
- **Deferred:** per-source lifecycle label sets, immutable source publication/activation, agent ACLs, advanced
  sharing/subscriptions, partial-feed degradation, automated ingestion for sources, per-source reminder leads, reminder quiet hours (requires
  an IANA timezone from the app), and widget refresh alongside reminder alerts.
  Implement these only when the task actually calls for them.
