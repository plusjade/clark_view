# Unified publish API spike

Status — 2026-10-03: phase zero and the first implementation slice are deployed;
device membership, widget integration, and reminders are not. See
[Implementation status](#implementation-status).

Clark View is a publication and delivery service. Producers own research,
computation, upstream access, and scheduling. A producer may be an agent, a
standalone program, or a feed adapter; all publish through the same API. Clark
View stores the resulting view and events, serves them to clients, and reports
whether the producer is meeting its declared maintenance cadence.

This spike is greenfield. Current source reads, registration data, conformance,
remote fan-out, managed slots, and current client reads are frozen while the new
path is built beside them. Legacy content, provisioning, and membership mutations
are disabled; the exact freeze boundary is below. Existing prototype data does not
migrate. Useful views and producers may be recreated against the new API, and
devices may rejoin them.

## Decisions

- `managed` is no longer a source kind. The managed-source workflow becomes the
  only publication workflow.
- A view is a logical publication boundary, not a runtime or database boundary.
- The parent owns view metadata, publication state, and one multitenant event
  table. Event identity and revision concurrency remain scoped to one view.
- Producers never serve widget reads. They publish state to Clark View and may run
  anywhere.
- The new read path queries parent storage directly. It performs no per-source
  network calls, pointer resolution, or conformance probes.
- Maintenance cadence is declared by the producer. A successful producer check is
  an explicit publication fact even when it changes no events.
- Physical source isolation, slot allocation, source remixes, source keys,
  registered endpoints, and source conformance are absent from the new path.
- Existing routes and tables are not evolved into this model. Their content and
  memberships become read-only before v2 implementation, and their reads remain
  until old clients and views are retired. No legacy write becomes an
  implementation dependency of v2.

RSS, ICS, and public JSON are inputs to producers, not alternate Clark View read
contracts. An external adapter may fetch one and publish normalized events. If a
native import is later justified, it is a Clark View-operated producer using this
same API and table rather than a second source architecture.

Device identity, widget response fields, presentation, lifecycle labels, reminder
delivery, and view membership are useful parent capabilities rather than source
architecture. The implementation may reuse their pure behavior, but the v2 store
must not depend on legacy source pointers or tables.

## Route boundary

Use explicit versioned paths. Headers make agent requests harder to inspect and
query parameters can accidentally select the wrong implementation. No v2 request
falls through to a legacy handler.

| Route | Purpose |
| --- | --- |
| `POST /v2/views` | Idempotently create a view and its initial publication |
| `GET /v2/views` | Discover available v2 views |
| `GET /v2/views/:id` | Read public view metadata and freshness |
| `GET /v2/views/:id/state[?scope=current\|all&cursor=]` | Read publisher state, revision, events, and compact inline guidance |
| `POST /v2/views/:id/publications` | Atomically reconcile metadata, intent, cadence, and events |
| `GET /v2/views/:id/publications[?limit=]` | Recent receipts and associated content changes for recovery |
| `GET /v2/events?viewIds=…` | Public pre-join composition |
| `GET /v2/devices/:id/views` | A device's v2 memberships |
| `PUT/PATCH/DELETE /v2/devices/:id/views/:viewId` | Join, change reminders, or leave |
| `GET /v2/devices/:id/events[?viewIds=…]` | Widget composition from the unified store |
| `GET /open/v2/views/:id` | Human preview and app handoff |

IDs are opaque strings at the HTTP boundary. V2 may allocate integer IDs
internally, but clients must not rely on that representation or reuse legacy IDs.
The v2 response can initially preserve the current schema-3 widget envelope so the
spike tests storage and publication rather than redesigning presentation.

V2 uses `clarkview://v2/view/:id` for its app handoff. The development client stores
the API generation with every view and widget selection; a bare legacy numeric ID
must never resolve as v2. Because migration is unnecessary, the v2 development
client clears old selections and requires an explicit rejoin instead of translating
them.

`agents.tamale.dev` should remain the memorable human and agent entry. During the
spike it may link to the canonical parent v2 routes. After acceptance, map it
directly to the parent or retain only a thin guide; do not retain a provisioning
service or forwarding hop without a demonstrated need.

## Storage

The minimum new tables are:

```text
published_views
  id, name, description, intent, revision,
  expected_check_interval_seconds,
  last_checked_at, created_at, updated_at

published_events
  view_id, event_id, main_text, sub_text,
  starts_at, expires_at, revision, created_at, updated_at
  PRIMARY KEY (view_id, event_id)

publication_receipts
  view_id, request_id, payload_hash, revision,
  checked_at, receipt_json, created_at
  PRIMARY KEY (view_id, request_id)

view_creation_receipts
  request_id PRIMARY KEY, payload_hash, view_id,
  receipt_json, created_at

publication_history
  view_id, revision, committed_at, actor_label,
  metadata_before, metadata_after, changes_json
  PRIMARY KEY (view_id, revision)

device_published_views
  device_id, view_id, reminders_enabled,
  last_built_at, created_at, updated_at
  PRIMARY KEY (device_id, view_id)
```

`published_events` is the one current-event table for every v2 view. Receipts and
history are operational records, not alternate event authorities. The first
implementation may keep full before/after changes in history because volumes are
small; retention can be revisited from observed growth.

Creation receipts are separate because creation retries do not yet have a view ID;
publication request IDs are scoped to a view so independent producers cannot
collide across views.

Every event read, write, count, receipt lookup, and history lookup includes its
view scope. A publication transaction may affect only one view. These are storage
invariants even while prototype authorization is permissive; sharing a database
does not permit cross-view revision conflicts or event identity collisions.

Reuse the existing `devices` rows so an installation does not need two identities.
Use a new membership table so v2 can be removed or rebuilt without interpreting
legacy `sources`, `device_lists`, feeds, or bindings.

All stored parent timestamps use the existing fixed-width ISO UTC convention.
Event windows remain integer Unix seconds internally and on the widget wire; the
publisher API accepts timezone-qualified ISO strings and normalizes them at its
boundary.

## Create contract

Creation retains the useful parts of managed-source bootstrap without allocation:

```json
{
  "requestId": "4c59eaf4-...",
  "name": "Lunar fifteenths",
  "description": "Upcoming lunar-month fifteenth days",
  "intent": "Publish the next relevant lunar fifteenth.",
  "expectedCheckIntervalSeconds": 86400,
  "checked": true,
  "agentLabel": "lunar publisher",
  "events": []
}
```

The transaction creates the view, initial events, revision 1, receipt, and initial
`lastCheckedAt`. Creation requires `checked: true`: it explicitly asserts that the
producer completed its initial check, and an empty `events` array means a checked
and currently empty result. Replaying the same request ID and body returns the same
result;
reusing it with a different body returns `409 request_id_reused`. There is no
pending provisioning or activation state. A committed view is immediately
discoverable and joinable.

The response returns `view`, `revision`, `stateUrl`, `publicationUrl`, `openUrl`,
and the publication receipt. Creation never joins a device, configures a producer
schedule, or proves that future maintenance exists.

Removing the slot pool also removes its capacity bound. Before a public creation
route ships, retain an `authorizeCreate` seam and enforce a code-owned global view
limit for the spike. Exhaustion returns `503 capacity_exhausted`; it never allocates
a runtime or claims a slot. Later access control may replace this guard. This is
resource protection, independent of per-view editor grants.

Every state/history management read and publication write also passes
`authorizePublish(viewId)`. The spike may keep that policy permissive because its
data is disposable, but source IDs and endpoint obscurity are never treated as
authority. This keeps later grants out of validation and persistence code.

## State and publication contract

The ordinary agent loop remains one state read and one publication:

1. Read state, including revision, intent, cadence, freshness, and relevant events.
2. Research or compute using the producer's own tools.
3. Publish metadata changes and affected events atomically.
4. If the producer completed the expected check, set `checked: true`, including
   when no event changed.
5. On a timeout or 5xx, retry the identical request ID and body. On a stale
   revision, reread state and re-evaluate.

```json
{
  "requestId": "a43ad4b8-...",
  "baseRevision": 7,
  "name": "Lunar fifteenths",
  "description": "Upcoming lunar-month fifteenth days",
  "intent": "Publish the next relevant lunar fifteenth.",
  "expectedCheckIntervalSeconds": 86400,
  "checked": true,
  "agentLabel": "lunar publisher",
  "upserts": [
    {
      "id": "lunar15-2026-10-25",
      "mainText": "Lunar 15th",
      "subText": "Cycle from Oct 11",
      "startsAt": "2026-10-25T12:00:00Z",
      "expiresAt": "2026-10-25T13:00:00Z"
    }
  ],
  "removals": []
}
```

Preserve the current managed API's validation, bounds, stable event IDs, complete
event upserts, explicit removals, conflict response, payload hashing, and actionable
field errors unless implementation finds a concrete defect. Event IDs are unique
within a view. Consumer composition namespaces them with the view ID.

`expectedCheckIntervalSeconds` accepts `null` to clear monitoring or an integer
from 60 through 31,536,000 seconds. Omission leaves it unchanged. The existing
rules continue to apply to omitted metadata, stable IDs, whole-second offset-aware
times, operation counts, stored-event counts, text lengths, and event duration.

A publication changes the view revision when metadata, intent, cadence, or event
state changes. A check-only publication updates `lastCheckedAt` and writes a receipt
without incrementing the content revision. It still requires the current
`baseRevision`, preventing a producer from claiming freshness against state it did
not read. A request with neither changes nor `checked: true` is a valid idempotent
no-op receipt.

Receipt lookup precedes the base-revision comparison. Replaying a committed request
returns its original receipt and original `checkedAt`; a late retry never advances
freshness a second time. `publication_history` contains content-changing revisions.
Check-only and unchanged publications appear in receipts, so multiple checks at one
content revision do not collide with the history primary key. The management
`GET .../publications` route returns receipts joined with change details when that
receipt created a content revision.

The first spike supports reconcile semantics only. A computed producer reads the
current state and derives removals. Do not add a replace-all or snapshot operation
until the compute proof or an RSS/ICS adapter shows that the extra read and diff are
material friction.

## Cadence and staleness

`expectedCheckIntervalSeconds` is nullable. Null means the view makes no ongoing
maintenance claim. It is an expectation for producer checks, not an event refresh
rate and not a Clark View schedule.

The server records its own time when a successful request asserts `checked: true`;
clients do not submit `lastCheckedAt`. Public state exposes:

```text
freshness.status       unmonitored | current | overdue | stale
freshness.lastCheckedAt
freshness.nextCheckDueAt
freshness.staleAt
freshness.expectedCheckIntervalSeconds
```

The initial heuristic is deliberately simple:

- `unmonitored`: no cadence is declared
- `current`: now is at or before `lastCheckedAt + interval`
- `overdue`: after one interval and at or before two intervals
- `stale`: after two intervals

This reports maintenance evidence, not data truth. Event coverage is limited to
observed earliest and latest stored event bounds unless a later contract lets a
producer assert completeness. An empty view or a far-future event does not prove
coverage and does not override cadence status. Change the heuristic only from
observed false positives or false negatives, not per-source tuning.

## Direct read path

Selection resolves v2 membership to view IDs, then one parent query reads relevant
rows from `published_events`. The result is globally ordered and passed through
the existing pure presentation, lifecycle, and widget-envelope behavior. There is
no source pointer, HTTP fan-out, source key check, conformance quarantine, or
partial network failure.

The read query must remain bounded by the existing selector limit, event horizon,
response byte limit, and widget item limit. A successful empty response still
includes its resolved view IDs so an empty selection remains distinguishable from
selected views with no current events.

Reminder building must eventually use the same stored event query. Until that is
implemented and verified, v2 reminder switches should remain unavailable rather
than silently reading legacy source endpoints.

## Compute-source proof

Use `plusjade/feed-lunar` because it has deterministic computation, no upstream,
no storage, and one-item output.

1. Keep its current HTTP entry on main unchanged while the parent v2 branch is in
   development.
2. On a source branch, extract the existing calculation into a callable pure
   function and add a publisher job.
3. The job reads `scope=all` through every page at one content revision, computes
   the desired event, upserts it, removes every other lunar ID including expired
   rows, and sends `checked: true` with one stable request ID per logical run. State
   pages carry their content revision; if it changes during pagination, restart the
   read before publishing.
4. Run it manually against a disposable v2 view, then schedule it only after the
   parent route is merged and the publication result is verified through the v2
   event read.
5. Retain or retire the old public GET only when its legacy view is no longer
   needed. It is not a fallback used by v2.

This proves that computation remains independently deployable while Clark View
owns publication. It also tests takeover state, no-change check-ins, removals,
retry safety, and cadence without involving an upstream API.

## Coexistence and branches

The read-only freeze is phase zero and is verified on the deployed legacy path
before publish-v2 work begins. Apply it as narrow changes to the parent,
`plusjade/managed-sources`, and every retained managed-source runtime. A runtime
that is not worth changing may be retired if no required legacy read depends on it.

Implement on one branch per independently deployed project:

1. `plusjade/app-clarkview:publish-v2` — additive schema, pure contract,
   publication store, v2 routes, direct composition, and parent checks. Legacy
   source modules and routes are unchanged except route wiring in `main.ts`.
2. `plusjade/feed-lunar:publish-v2` — publisher adapter and its own checks. Begin
   after the parent contract is stable enough to consume; do not merge it first.
3. This iOS repository on `codex/publish-v2-client` only after the parent proof —
   point an explicit development path at v2, then verify create/join/read/widget
   behavior without compatibility aliases.

Val Town branches share the parent SQLite database. A code branch is not a data
sandbox. Branch work may create only additive v2 tables and uniquely named
disposable v2 fixtures; it must not mutate legacy schema or data. Pre-merge HTTP
probes must address the branch endpoint explicitly, record their fixture IDs, and
delete only those fixtures. The Lunar interval remains disabled on its branch and
through the parent merge; enable it only after its destination is the verified main
v2 endpoint.

Merge the parent only after its core checks and representative v2 create, no-op
check, edit, conflict, replay, selection, and direct-read probes pass. Merge the
lunar producer after one publication is visible through the parent read route.
Client cutover follows server and producer evidence.

Do not dual-write, mirror legacy data, translate source registrations, or preserve
legacy IDs. Coexistence is route-level: v1 reads its existing tables and remote
sources; v2 reads its new tables. Recreate a useful view in v2 and explicitly join
test devices there. Retirement is deletion or disabling of old routes and data in
a later, separately verified change.

Before v2 implementation, freeze the legacy publication system:

- disable managed creation, initialization, reconcile, metadata refresh, source
  registration/replacement, and legacy view/feed membership mutations;
- keep canonical source GETs, view/feed/event reads, and existing joined-device
  reads available;
- continue shared operational writes needed by both generations: device
  registration, push-token maintenance, widget inventory, and request receipts;
- return an explicit read-only error from frozen mutations rather than pretending
  they succeeded.

Individual managed-source write endpoints must also be disabled or their sources
retired; freezing only the parent would still allow their remote output to change.
Computed GET sources may remain dynamic until retired, but no legacy registration,
membership, or editorial state changes.

Reusing `devices` also reuses their lifecycle. For the spike, reject a device merge
with `409 v2_memberships_present` when either device has v2 memberships. Device
deletion cascades through `device_published_views`. Revisit merge preservation only
if v2 acceptance shows that merging is still a real workflow.

## First implementation slice

The smallest end-to-end slice is:

1. Verify the phase-zero legacy read-only boundary.
2. Add v2 tables and pure create/reconcile/freshness rules.
3. Add create, state, publication, public view, and public event-read routes.
4. Verify atomicity, revision conflicts, retry receipts, source-scoped IDs,
   check-only freshness, and a multi-view direct read in the parent runner.
5. Publish the lunar result from its producer branch and verify it through
   `GET /v2/events`.

Device membership and widget integration are the next slice, with distinct v2
identity and reset/rejoin acceptance. Reminder reads are a third slice; they have
delivery side effects and are not needed to prove the new source boundary.

The spike is successful when a standalone compute job and an agent-style request
can create or curate separate views in the same parent event table, a no-change run
advances freshness, direct composition performs no source fetches, and every
retained legacy read remains available while prohibited legacy mutations return
the explicit read-only error.

## Implementation status

Observed 2026-10-03. Close this section when slice 2 ships or the spike is abandoned.

| Piece | State | Pointer |
| --- | --- | --- |
| Phase zero freeze | Deployed; mutations return `423 legacy_read_only` | Parent `http/routes/legacyFreeze.ts` (v463); `manage.ts` in each managed slot and the template; provisioner `main.ts` |
| Slice 1: tables, contract, routes | Deployed, parent `main` v464 | `lib/publishContract.ts`, `lib/publishStore.ts`, `lib/publishGuide.ts`, `http/routes/publishV2.ts`; `tools/publish-v2-check.ts` in the runner |
| Lunar producer | Merged; daily interval `7 16 * * *` UTC publishes to `pv_11` | `plusjade/feed-lunar` `publish.ts`, `publisher.ts`, `tools/check.ts` |
| Slice 2: v2 membership, `/v2/devices/:id/*`, iOS client, merge guard | Not started | — |
| Slice 3: reminders from `published_events` | Not started | — |

Decisions made during implementation:

- View IDs are `pv_<n>` over an AUTOINCREMENT integer, so a deleted view's ID is
  never reissued and a legacy numeric ID never parses as v2.
- `GET /v2` serves the agent creation guide; state reads embed the update guide.
  `agents.tamale.dev` links to it.
- `device_published_views` and the `409 v2_memberships_present` merge guard ship
  with slice 2; neither has a caller before v2 membership exists.
- A creation also writes a publication receipt and history revision 1, so
  `GET .../publications` lists it.
- Capacity is 50 views (`LIMITS.views`).
