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

**Work status — 2026-10-02:** the public agentic managed-source milestone is
accepted. The user verified agent creation/curation, iPhone open/join and app →
agent editing, widget delivery after refresh, and scheduled continuity within a
simulated time-frame. See [managed-source-plan.md](managed-source-plan.md) for the
acceptance scope. No implementation or UAT hold remains for that milestone.
Legacy browser surfaces (feed management and joins, source → feed attachment, and
source diagnostics UI), `/config/*`, `/devices/resolve`,
`/installations/:installId/feed`, and the 410 pairing stubs were removed in parent
`main` version 456 (2026-10-02, `tools/check.ts` passing). Migration of all prototype
devices and retirement of remaining legacy JSON APIs and data require separate scope;
do not infer that migration has happened. Authentication and friendly editing URL
routing are deferred, not active tasks. Existing per-source
editing URLs remain valid. Older compatibility/accessibility/APNs notes are
unclaimed coverage for future scoped work, not instructions to restart this UAT.

**Active spike — 2026-10-03:** [publish-api-spike.md](publish-api-spike.md) slice 1
is deployed (parent `main` v464). The parent owns v2 views and one multitenant event
table; producers publish through `/v2`; `GET /v2/events` reads parent storage directly.
Legacy publication is frozen: parent membership and managed-refresh writes, the
provisioner's `POST /managed-sources`, and every managed slot's
initialize/reconcile return `423 legacy_read_only`. Legacy reads, conformance probes,
device registration, tokens, inventory, and receipts continue. Legacy reminders are paused.
`plusjade/feed-lunar` publishes daily to v2 view `pv_11`. Slice 2 (parent v465) adds
v2 device membership and `/v2/devices/:id/events`; the iOS client on `main` reads only
v2. Creation requires a maintenance declaration (parent v466). `plusjade/feed-rams`
publishes to `pv_29` after each six-hour refresh. Slice 3 (parent v467) builds reminders
from `published_events`; both reminder crons run only the v2 pipeline.

Clark View is widget-first. The containing iOS app registers its own install, manages
joined **views** (each with a preview and producer freshness) on the home screen,
and exposes notification setup and diagnostics through its menu. In the app, a view is
a published v2 view whose events live in the parent; legacy views are each backed by
one registered source and are read only by older builds. Widgets display events from
all joined views or a selected subset. The browser administers device identity and
inspects sources and widget activity.

“View” is the product word. Existing `list`/`source` implementation names, storage,
source IDs and saved widget identities remain unchanged; public routes and wire fields
use `view`/`views`. A view is neither
a widget placement nor a saved multi-source composition. The name adds no filters,
per-view appearance, private variants or ownership privileges. Joining and reminder
preferences remain device-specific; shared edits affect everyone joined.

Feeds remain as compatibility infrastructure: app builds that predate direct source
membership read `/feeds/:feedId` and `/devices/:id/subscriptions`. A widget placement
that saved a feed keeps it through the server-side `feedId` bridge. Nothing converts
feed data into views, and there is no retirement date for the retained APIs; retire
by observed old-client and widget usage.
Feeds have no browser views: feeds, assignments, presentation, and timing are frozen
and change only by direct database operation.

```text
Browser → app-clarkview → devices, source registry, widget activity
App     → app-clarkview /views, /devices/:id/views, /events?viewIds=…; POST /devices and status identify an install
          (compatibility: /devices/:id/subscriptions, /feeds/:feedId for feeds joined earlier)
Widget  → app-clarkview /devices/:id/events[?viewIds=…|?feedId=…]
                         → selector → view IDs (membership, selection, or the feed's enabled assignments)
                         → public HTTP reads of those source vals
                         → validate items, sort, attach global presentation → widget schema 3
Old builds → app-clarkview /feeds/:feedId (unchanged)
Source ingest → that source's own schedule → its own SQLite
app-clarkview → best-effort APNs → WidgetKit → normal events fetch
```

| Concern | Owner / first place to inspect |
| --- | --- |
| Layout, family limits, local date/time, empty state, interaction, reload scheduling | This repository: `ClarkViewWidget/` and `Shared/`; [ios-widget.md](ios-widget.md) |
| Enrollment, registry pointers, membership, browser operations, composition, global presentation, push delivery | `plusjade/app-clarkview` (the parent) |
| Team vocabulary, selection, event/status/broadcast text, upstream normalization, storage, ingestion | The implementing `plusjade/source-*` val |
| New source authoring | Remix `plusjade/source-template`; update its canonical `source.json`, then follow `AGENTS.md` for implementation and external verification |
| v2 publication (views, events, receipts, freshness, direct reads) | Parent `http/routes/publishV2.ts`, `lib/publishContract.ts`, `lib/publishStore.ts`, `lib/publishGuide.ts`; agents start at `GET /v2` |
| v2 producers | Their own code and schedule; e.g. `plusjade/feed-lunar` `publisher.ts` |
| Agent-published managed source (frozen) | `plusjade/managed-sources` and slot remixes of `plusjade/managed-source-template`; reads serve, writes return `423` |
| Source contract and item validation | Parent `source/README.md`, `source/readContract.ts`, `lib/sourceContract.ts` and `lib/canonicalSource.ts` |
| Whether a source is trusted to serve, and why | Parent `lib/sourceConformance.ts` and `docs/source-conformance.md` |
| Widget wire fields or their meaning | Coordinate source output, parent composition, Swift decoding, fixtures, and tests |

Do not put source-domain policy in Swift or source-specific dispatch in the parent's
generic composition path. The parent understands temporal view items; it has
no internal games model. There is no intermediate feed val.

Classify the task before reading anything else. Each route is a budget, not a minimum:

| Task | Read | Do not load |
| --- | --- | --- |
| Widget layout, diagnostics, deep links | [ios-widget.md](ios-widget.md) and the Swift it names | This file past the ownership map; any remote val |
| New source authoring | `plusjade/source-template`'s `AGENTS.md`, then its README | Parent implementation; sibling sources |
| v2 publish API or a v2 producer | [publish-api-spike.md](publish-api-spike.md), then parent `lib/publish*.ts` and `http/routes/publishV2.ts`, or that producer's README | Legacy source, list, feed, and managed modules |
| Managed source behavior or guidance (frozen) | That source's `AGENTS.md`, README, and inline state guide; for a new slot, the managed template and provisioner READMEs | Sibling source code and parent implementation |
| Source behavior, storage, or ingestion | That source's own README and `AGENTS.md` | Parent modules; sibling sources |
| Parent routes, composition, browser, wire contracts | The code map below, then only the implicated parent modules | Swift; unrelated parent directories; other vals |

## Design intent

A source is an independently operated capability, not a table — the point is letting
agents publish views without deploying application code into the parent. The intended
lifecycle is sandboxed authoring → deterministic validation → immutable release →
pointer activation → contract-conforming serving; only pointer activation and serving
are implemented today (see "Deferred" below). Items, facets, and options are the
default data model; a custom implementation can expose the same contracts through a
separately authorized code deployment path.

The target is independent sources with a small, stable contract, not identical
sources. The implementation can remain replaceable without creating a
release-management system around it. Every source remix, managed or computed,
is an independent point-in-time copy. Its code, guidance, and data may evolve
for that source. Change an existing source to fix a defect, alter intended
behavior, or complete a required contract migration, not to keep cosmetic prose
or implementation identical to a template. Parent registration, verification,
joins, and widget delivery remain in the parent; bounded managed-source creation
belongs to `plusjade/managed-sources`.

Prepared managed slots have parent-owned inactive bindings and are hidden from view
discovery and joins until initialized. Creation returns ready only after the parent
verifies and activates the bound view. A delayed activation keeps the same claimed
slot; retry the original request. The runtime's optional metadata adapter projects
name and description into the parent with a revision guard; event-only edits do not
call the parent. Source identity, registered endpoint, view ID, conformance and
membership remain parent-owned. Joining is not ownership; shared edits affect all
subscribers. See parent `docs/lists.md` and `docs/get-sources.md` for preparation,
activation and recovery.

Creation returns a human `/open/views/:id` link with a preview and a
`clarkview://view/<id>` app handoff. The app fetches authoritative metadata and
offers an explicit Join, or opens an existing membership. Its managed-view detail
can copy instructions pointing an agent at live state and guidance. This passes no
device identity or token and imposes no agent research or scheduling workflow.

The generic feed composer deliberately lives in the parent, next to pointer
resolution, rather than in its own composer val: parent → composer → source would add
a hop and distribute pointer/credential management before there's a need. Composition
is kept as a pure helper so it can move later if that changes.

## Stable deployment identities

**[agents.tamale.dev](https://agents.tamale.dev/)** is the public agent entry, served
by `plusjade/managed-sources`. Its `GET /` points to the parent's `GET /v2` guide;
`POST /managed-sources` is frozen. Existing managed views' `manageUrl`s still read.

The parent is `plusjade/app-clarkview`, branch `main`, public code/public app access.
Its HTTP entry is **`main.ts`**, file ID **`f0eeffb8-9a93-11f1-9bb6-1607ee4eb77e`**,
endpoint **`https://plusjade--f0eeffb89a9311f19bb61607ee4eb77e.web.val.run/`**.
[ServerURL.swift](../Shared/ServerURL.swift) owns the same iOS base URL.

The parent homepage's Open Graph image is owned by `plusjade/og-clarkview`, branch `main`,
public code/public app access. Its HTTP entry is **`main.tsx`**, file ID
**`01a1008b-2ff6-70db-8ae1-c6b7fca7c6e8`**, endpoint
**`https://plusjade--01a1008b2ff670db8ae1c6b7fca7c6e8.web.val.run/`**. The
extension selects the representation: `/app.svg` is the programmatic source and
`/app.png` rasterizes that SVG. Both default to 1200×630; the same routes accept
`?orientation=portrait` for 630×1200. The parent emits the landscape PNG URL and its
dimensions in `render/rootHtml.ts`. Preserve the HTTP file identity when changing the
image service, and use the SVG builder in `image.ts` as the visual source of truth.

**Preserve the HTTP file's identity: update it in place; do not delete, recreate, or
rename it.** Endpoint identity follows the file ID, not its name. When verification is
needed, use `links.endpoint` from `list_files`; do not invent URLs from val
names. Keep iOS on this endpoint — do not substitute an unverified alternate host.

Sources are registered system-wide. IDs identify parent-owned instances, not
universal source kinds. Every source uses the public HTTP entry point defined by the val. During this
prototype stage, all source operations are intentionally unauthenticated, including
reads, diagnostics, ingest triggers, and other writes. Endpoint obscurity is not
authentication. Registration, activation and membership remain parent-owned
operations; legacy feed assignments have no write route.

**Registration is not trust.** Each row also carries live conformance metadata —
`conformance_state`, `conformance_checked_at`, `conformance_verified_at`,
`conformance_detail` — written only by the parent's probe, and **only a `verified`
source reaches a composed feed or a reminder**. Those values change on every probe, so
read them from `/sources` (Verification column) or a source's Overview tab rather than
caching them here.

## Parent model and code map

Canonical parent tables include `devices`, `sources`, `device_lists`,
`feeds`, `feeds_sources`, `device_subscriptions`, `device_push_tokens`,
`device_alert_tokens`, `subscription_notification_queue`, `device_widget_inventory`,
`device_feed_requests`, and `device_event_requests`.
`device_lists` is view membership: a unique device/source pair with `reminders_enabled`
(default off). `sources.reminder_lead_seconds` (default 3600) is a view's reminder lead; it has
no editor. Parent `docs/lists.md` owns the view model, routes, and recovery snapshot.
`feeds` retains independently allocated stable IDs, nonunique names,
presentation, shared `reminder_lead_seconds`, and timestamps. `feeds_sources` has a unique feed/source pair,
foreign keys, and a Live/Disabled flag. Neither table has device ownership,
surface type, or ACL. Feeds, their presentation and assignments are frozen with
no browser or route editor. Sources own their data separately.

- `sources` is a system-wide instance registry: `id`, `name`, `endpoint`,
  `remote_source_key`, `contract_version`, `read_profile`, plus timestamps. `read_transport`
  and `settings_schema` are inert leftovers of the retired protocol. `kind` is unrestricted diagnostic metadata, neither unique
  nor the transport dispatch key. There is no separate definitions or
  `source_instances` table.
- An install creates its own device row independently of feed joins.
- A reinstall registers a new device row; `/devices/:id/merge` moves its live
  install ID onto the target and deletes the origin. Feed IDs and content are untouched.
  The retired install ID's push/alert token rows are dropped.
- `feeds_sources` stores source instance IDs without device membership.
  These assignments are frozen; no browser or route edits them.
- A `device_subscriptions` row means joined. Its `enabled` boolean means reminders
  are on; timing always comes from the feed. Feed attachment, widget selection, and
  device registration never create a join implicitly.
- The legacy `priority` column is inert. Composition orders by item start time, then
  source ID and source-local item ID. No current form sets priority.
- Feed assignment `enabled` is a non-null 0/1 flag. Live (1, default) contributes
  to public composition; Disabled (0) stays attached. An enabled unverified source
  is withheld and diagnosed. There are no assignment state controls.
  Installation-keyed resolvers are retired; their frozen mapping is retained data only.
- Source pointers are trusted parent configuration; nothing device-side can override
  destinations. Item IDs become `<source-id>:<local-id>`, remaining stable across a
  compatible endpoint change.
- Assigned sources execute concurrently. A failed source fails the whole composition;
  partial-feed degradation is not implemented.
- The one-time `independent-feeds-v1` migration copied every then-current device row,
  including empty rows, into `feeds` with the same ID, name, presentation, and
  timestamps. It copied all assignments including Disabled and froze installation
  mappings in `legacy_installation_feeds`. No current route reads that mapping;
  it is not a rollback target. Later device creation creates no feed.
  Directory order is name (case-insensitive), then feed ID. A known empty feed succeeds;
  an unknown or deleted feed returns JSON 404.

| Parent path | Responsibility |
| --- | --- |
| `main.ts`, `http/routes/*.ts` | Stable Hono wiring, iOS routes, browser administration; no parent ingest route |
| `lib/sourceClient.ts` | Source lookup, canonical GET read, item guards, `composeFeed` |
| `lib/listStore.ts`, `lib/listSelector.ts`, `http/routes/lists.ts` | View directory, device membership, selector parsing and resolution, events routes |
| `lib/feedStore.ts` | Read-only legacy feed directory, composition lookup, and frozen legacy mapping |
| `lib/sourceStore.ts` | Registry and browser source projections |
| `lib/deviceStore.ts` | Device identity |
| `lib/presentation.ts` | Global events presentation and legacy stored presentation parsing |
| `lib/deviceTokenStore.ts`, `lib/push.ts` | Token lifecycle and best-effort device notification (`notifyDevice`) |
| `lib/publishReminders.ts` | v2 reminder builder and drainer over `published_reminder_queue` and `published_events`; delivery capability |
| `lib/subscriptionStore.ts` | Paused legacy feed and list reminder authorization and ledger; still covered by its check |
| `lib/widgetObservationStore.ts`, `http/routes/widgetObservations.ts` | Device-reported widget inventory, feed- and event-request receipts, `/devices/:id/widgets`; parent `docs/widget-inventory.md` |
| `lib/subscriptionBuilder.ts`, `lib/subscriptionDrainer.ts` | Paused legacy reminder builder and drainer; no cron or route calls them |
| `crons/buildReminders.ts`, `crons/drainReminders.ts` | The two v2 reminder schedules |
| `lib/lifecycle.ts` | Global lifecycle label set; phase-to-word resolution and the derived legacy caption |
| `lib/guards.ts` | Domain-free runtime guards |
| `render/pageShell.ts` | Browser styles, semantic hierarchy, navigation and shared form/table rules |
| `render/deviceHtml.tsx`, `render/sourceHtml.tsx`, `render/widgetObservationHtml.tsx` | Device identity operations, source explorer, widget activity |
| `render/rootHtml.ts`, `render/dataTable.tsx` | HTML root and shared tables |

Browser work follows `AGENTS.md`: native semantic HTML, compact data-dense views,
shared `pageShell` styles and the existing resource navigation. React is not a
reason to add a component library or client-side JavaScript.

The shared browser header links Home to `/` and displays an alphabetically ordered,
horizontally scrolling story-style gallery. `main.ts` fills `pageShell`'s single
gallery slot only in HTML responses; JSON routes do not load navigation data.
`/sources` and its subroutes show sources; other browser routes show devices.
Human `/open/views/:id` pages omit administration navigation. Resource pages mark the current resource.
Browser tab titles retain resource names. The root is a public standalone landing
page with the centered product tagline and Open Graph metadata, but no links. Direct
administration routes retain their own navigation; the root is intentionally not a
crawlable directory of those routes.

## HTTP contracts used by iOS and the browser

| Method / route | Behavior |
| --- | --- |
| `GET /views`, `GET /views/:id` | View directory (`{views:[…]}`) and detail: `{id,name,description,reminderLeadSeconds,available,availability}`. IDs are decimal strings opaque to Swift. JSON only, `no-store`. |
| `GET /devices/:id/views` | This device's `{views:[…]}` with `remindersEnabled`, plus `delivery`. `:id` is the device row. |
| `PUT` / `PATCH` / `DELETE /devices/:id/views/:viewId` | Join (201 new with reminders off, 200 existing and unchanged), set `{remindersEnabled}` (404 if not joined), leave (idempotent). |
| `GET /events?viewIds=1,2` | Public composition for a pre-join preview. The selection is required; an unknown ID is 404. |
| `GET /devices/:id/events` | Events for all joined views, or `?viewIds=` intersected with membership, or `?feedId=` (a retained legacy feed selection, resolved to its enabled assignments and not intersected with membership). Selectors are mutually exclusive; empty, malformed, or duplicated ones are 400 and never mean all. Unknown device or feed is 404. The body adds `selection:{mode,viewIds}`. Presentation is one code-owned global policy. Receipt headers record only for the device's own installation. Parent `docs/lists.md` owns the contract. |
| `GET /feeds` | Public directory: `{feeds:[{id,name,reminderLeadSeconds}]}`. Timing is the feed's current shared value; IDs are decimal strings opaque to Swift. No installation identity is required. Read-only and `no-store`. |
| `GET /feeds/:feedId/details` | Public name, shared timing, and attached sources (`id`, `name`, diagnostic `kind`, and `enabled`) for native detail surfaces, without changing widget payload semantics. |
| `GET /feeds/:feedId` | Public schema-3 composition from a feed's enabled and verified assignments and presentation. Optional `timeZone` reader context. Unknown or deleted IDs return JSON 404; a valid empty feed succeeds. Reads use `no-store`. Optional `X-Clark-Installation`, `X-Clark-Caller`, `X-Clark-Widget-Family`, `X-Clark-Request-Purpose` headers record a receipt for a registered device only; they never change the response. |
| `POST /device/widget-inventory` | `{device,observedAt,widgets:[{kind,family,state,feedId?,mode?,viewIds?}]}` complete snapshot; `state` is `configured`/`unconfigured`/`unreadable`. `mode` is `all`, `selected` (with `viewIds`), or `feed` (with `feedId`); absent on builds that predate direct source membership. Replaces the stored snapshot unless older (`{ok:true,stale:true}`). Unknown install 404, malformed 400. |
| `POST /devices` | App sends `{device}` on first run. Creates its row if missing and returns 200 `{ok:true,id,paired:false}`; an existing row is never changed. Retained `paired` is compatibility-only. |
| `GET /devices/status/:installId` | Registration diagnostics: `{deviceId,registered,paired:false,name,id}`; unknown install omits name and id. The app re-resolves `id` on each load because a merge moves the install to another row. Remove `paired` after old clients are gone. |
| `POST /device/token` | `{device,token,kind:"widget",environment:"sandbox"\|"production",active}`; `active:false` removes the token. Legacy omitted fields support old app-background tokens. |
| `GET /` | Public HTML landing page with the product tagline and Open Graph metadata; contains no navigation links |
| `GET /devices/:id`, `POST /devices/:id/settings` | Device identity/settings page and name update; the page links to merge and Widgets |
| `/devices/:id/subscriptions` | Legacy iOS join API, always JSON with no browser view. GET returns `{subscriptions:[{id,feedId,feedName,enabled,reminderLeadSeconds,createdAt,updatedAt}],delivery}`; `reminderLeadSeconds` is derived from the feed, not stored per device. Create/update accepts `enabled=0\|1`; delete leaves. Legacy `leadSeconds` on create with no enabled means on and is ignored on update until old clients age out. Duplicate join returns success without adding a row. |
| `/devices/:id/widgets` | Widgets tab: latest reported widget inventory, and request receipts per selector (events routes) or feed (legacy), caller, family, and purpose, labeled with report times |
| `/devices/:id/merge` | Move a reinstalled app's install ID onto the device it replaces; the chosen target survives and the origin row is deleted |
| `/sources` | Read-only registry explorer with the source gallery in place of the device gallery |
| `/sources/:id` | Source Preview tab: reads the implementing source without settings and renders temporal items plus the raw source response; failures and empty feeds remain ordinary page states |
| `/sources/:id/overview` | Registry metadata and verification |
| `/sources/:id/diagnostics` | Retired path; redirects to the source Preview with 301 |
| `POST /internal/reminders/{build,drain}` | v2 reminder jobs behind `REMINDERS_TOKEN` bearer auth; unset returns 401. Drain accepts an optional row `id`, keeping an external scheduler swappable for the cron. |

Retired parent routes are not supported compatibility or rollback targets:
`/feeds/manage`, `/feeds/new`, feed management/assignment writes,
`/installations/:installId/feed`, `/config/resolve`, `/devices/resolve`,
`/config/status/:deviceId`, `/pair`, `/devices/register`, and `/sources/:id/feeds`.
Retained legacy reads and subscription writes are listed above. Their continued
existence does not establish that every old app build remains supported.

Composition diagnostics include `x-device-feed-provider: source-registry-v1`,
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
its identifier. The removed installation-keyed resolver is not a supported `tz` offset path.
The parent does not persist named zones or forward numeric offsets to sources.
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
GET checker and serving guards before recording conformance. Registration is a manual
operator action; parent `docs/get-sources.md` ("Publishing a view") owns it. A registered,
verified source is a view anyone can preview and join; publication needs no feed and
writes none, and it joins a device only when that is separately authorized. The procedure
requires writing `read_profile` explicitly and omitting `reminder_lead_seconds`. Publication
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
- **Events routes use one global presentation** (`GLOBAL_EVENTS_PRESENTATION`: Beacon,
  version 2, white/black roots, expired items kept) for every selector, including a
  bridged `feedId`. Stored feed presentation is frozen at the compatibility boundary: it
  still serves `/feeds/:feedId` and is neither evolved nor imported into views.
- Events routes add `selection:{mode,viewIds}`: the views the selector resolved to. An
  empty `viewIds` means nothing was selected, which Swift shows as a join or edit prompt;
  eligible views with no events render the ordinary empty state. Legacy feed reads omit it.
- Legacy feed presentation stores `intradayFilter` (default false), with no editor. `composeFeedItems` applies `expiresAt > now` after validation
  and composition with one clock snapshot across sources. Legacy feed reads use it;
  events routes retain expired items, and reminder eligibility is independent of
  presentation. This server-only setting is omitted from the
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

**v2 reminders (parent v467, 2026-10-04).** A v2 membership with reminders on gets one
alert per upcoming event at a fixed one-hour lead (`REMINDER_LEAD_SECONDS`), built from
`published_events` within a 36-hour horizon. A build refreshes each candidate row and voids
the device's pending rows it did not touch, so a moved event reschedules and a removed one
cancels. The drain revalidates membership, the toggle, and the event's window before
claiming and sending; turning reminders off or leaving voids pending rows. The queue has
no foreign keys so terminal history outlives memberships. Legacy feed and list reminders
are paused: no cron builds or drains them, and their pending rows were voided as
`LegacyRemindersPaused`. The legacy description below is retained for context.

**Cutover status (observed 2026-09-24).** The implementation was merged from
`independent-feeds` into parent `main` version 387. The shared database copy's
both-direction value comparisons matched
five copied feeds and seventeen assignments. Live `/feeds`, `/feeds/:id`, and
`/feeds/manage` respond, parent `tools/check.ts` passes on `main`, and a
disposable feed/device isolation fixture passed and was removed. One iPhone 17
simulator had an installed but unconfigured widget; the bounded UI attempt did not
reach its Feed picker. That legacy feed selection/edit/refresh scenario was not
reported as passed. As of the 2026-10-02 managed-list acceptance, it is retained
only as compatibility context for the next user-scoped legacy cleanup, not an
active UAT hold. Managed-list widget delivery after refresh is accepted separately.

The join-feed cutover was merged into parent `main` on 2026-09-26 (through
version 450). Feed timing
was migrated from unanimous subscription values, using one hour for feeds with
no subscriptions. Bunch tables and `bunch_id` columns, plus per-subscription
timing, were removed after a recoverable snapshot. See
[join-feed-cutover.md](join-feed-cutover.md) for preservation and recovery.
For current operation, check `read_interval_settings` and the two cron file logs;
the parent `docs/subscriptions.md` owns the reminder contract. The prior
subscription deployment's scheduled times are historical, not current settings.

A reminder is authorized by either of two paths. A view membership with reminders on
follows that verified source at `sources.reminder_lead_seconds`. A legacy enabled feed join
follows current enabled, verified `feeds_sources` at the shared feed lead, independent of
feed presentation and widget selection. Both write the same queue; a same-device,
same-event, same-lead overlap is one row and one alert, and turning off or leaving one
path never cancels a row the other still authorizes. The builder must sync one combined
candidate set per device, because the sync voids what it is not given. The ledger deduplicates overlapping feeds by device, namespaced
item ID, and lead; terminal results are not replayed. `REMINDERS_ENABLED` gates APNs
delivery. Alerts do not refresh the widget. Quiet hours require a
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
Sources take no settings, so nothing device-side narrows a source response.
Legacy feed presentation owns its expiry filtering; events routes retain expired items. See the parent's `docs/intraday-filter.md` for the contract.
Default durations are source-owned named constants (Lunar's one-hour event window and
siblings); the parent may not supply one.

Source-specific storage coverage and freshness diagnostics belong to each source.
The parent no longer fetches a source diagnostics endpoint or exposes a Diagnostics
tab; `/sources/:id/diagnostics` only redirects to Preview. Inspect the owning source
README and its supported diagnostics when coverage is in question.

Computed and upstream source implementations include `plusjade/feed-lunar`, `feed-gtb`, `feed-rams`,
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
| Composition | Events routes, retained legacy feed reads and the source Preview; empty and mixed-source fixtures; namespaced IDs, ordering, ties, diagnostics, source failure, malformed output | A successful *empty* response doesn't prove an assigned source actually works — check `x-effective-sources`, then `x-quarantined-sources` |
| Conformance | The probe against every registered source, and that only a verified one reaches a feed. Core suite covers gating, staleness derivation and quarantine diagnostics | A green feed says nothing about a source nobody has re-probed — check `conformance_verified_at`, not just the state |
| Source | Public `GET /`, its 400/405 rejections, nonempty fixtures, timezone edges. Source-owned checks | Diagnostics reporting "unavailable" means unknown coverage, not zero |
| New GET source | External `/source-verifications` against the remix's own endpoint and key; parent changes run `tools/check.ts` | A pass does not register or activate a source, prove data accuracy, or establish nonempty coverage |
| Views | Membership and preference round trips; all/subset/`feedId` selection; empty versus invalid selectors; conformance withholding; the same event IDs and order as the legacy feed read. Core suite covers these | A successful empty body does not prove a view contributed — check `selection.viewIds`, `x-effective-sources`, then `x-quarantined-sources` |
| Widget contract | Decode a representative composed response with Swift; update preview fixtures/tests; build app and widget for contract changes (`xcodebuild -project clark_view.xcodeproj -scheme clark_view build`/`test`); run SwiftLint | — |
| Push | Verify token environment/topic and actual delivery separately per environment | APNs *accepting* a request is not proof a banner appeared — use console delivery logs; a simulator build proves nothing about real APNs delivery |
| Reminders | Core suite; a disabled drain for queue processing | A disabled run exercises queue processing without proving APNs delivery; the builder still writes live queue state |
| Browser | Public `/` and query-bearing root return the landing page; exercise the changed administration resource route separately | Root access does not prove administration navigation or resource pages work |

Do not use production writes as casual smoke tests. Enrollment, assignments, names,
tokens, ingest and schema operations mutate state — use scoped disposable fixtures and
clean them up, accounting for shared SQLite even on branches. Prefer read-only route
diagnostics, then narrow, parameterized `sqlite_execute` queries with
`mode:"read"` and the exact owning val database. Do not put install IDs, capability
IDs, pairing codes, APNs tokens or secret values into chat, logs, fixtures or this
repository.

For a blank/stale widget, trace in order: app refresh diagnostics → events response
and selector/effective sources → membership or retained legacy assignments → source
read/coverage → ingestion. A push/reload cannot repair missing membership, an empty
selection, or a stale source cache.

## Gotchas and deliberately unfinished work

Keep these constraints; use Git/Val Town history for change lists and old probes.

- **Compare absolute instants at timezone boundaries.** Scanning UTC buckets from a
  client-local date floor drops valid events at UTC+14.
  Each non-sports source retains its own date-selection semantics; a timezone redesign requires
  source-specific fixtures, not a blanket shift of timestamps.
- **Rebuilding `sources` can delete assignments.** Foreign keys are on and
  `feeds_sources` cascades on delete. The join-feed cutover preserved assignments
  by restoring their captured rows in the same transaction; future rebuilds need
  the same explicit preservation and verification strategy.
- **Do not replay completed token backfills.** `INSERT OR IGNORE` only skips rows
  still present, so replaying a backfill after a dead-token cleanup can resurrect
  retired tokens. Schema initialization must not recreate the retired `device_tokens`
  table, and lookup prefers a device's widget token; preserve both when changing token
  persistence.
- **v2 view IDs are `pv_<n>` and never reused.** `published_views` uses AUTOINCREMENT;
  a bare number never resolves under `/v2`. Disposable v2 fixtures share the parent
  database across branches: record their IDs and delete only those rows.
- **Remixes can retain credentials.** Unused inherited keys can remain in a remixed
  val; there is no delete-env operation in the current MCP tooling. Do not assume
  cleanup of copied secrets happened, or bundle it into an unrelated change.
- **Deferred:** per-source lifecycle label sets, immutable source publication/activation, agent ACLs, advanced
  sharing/subscriptions, partial-feed degradation, automated ingestion for sources, a reminder lead editor or per-device lead override for views, saved view groups, legacy feed/route/table retirement, reminder quiet hours (requires
  an IANA timezone from the app), and widget refresh alongside reminder alerts.
  Implement these only when the task actually calls for them.
