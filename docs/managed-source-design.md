# Managed sources: phase 1 design

Status: **proposed, not deployed.** Phase 1 deliverable of
[managed-source-plan.md](managed-source-plan.md), 2026-09-30. Nothing here is
current behavior. Awaiting review at the phase 1 STOP before any implementation.

## Decisions at a glance

| Question | Proposal |
| --- | --- |
| Runtime | New `plusjade/managed-source-template`; each source is its own remix (val runtime + val-scoped SQLite) |
| Creation | New `plusjade/managed-sources` provisioner val claims a slot from a prepared pool; no Val Town API calls at request time |
| Capacity | 5 operator-prepared slots `plusjade/managed-source-01…05`; claimed slots are never recycled; exhaustion returns 503 |
| Parent | No code changes. Slots are registered and probed at pool prep through the existing [get-sources](https://www.val.town/x/plusjade/app-clarkview/code/docs/get-sources.md) runbook; a human attaches a claimed slot to a feed |
| Wire | Canonical `GET /` unchanged. Management lives under `/manage/v1/*` on the same HTTP entry |
| Time input | RFC 3339 with `Z` or `±HH:MM`, whole seconds; nothing else |
| Atomicity | One `sqlite.batch` per publication; `publications.revision` primary key is the compare-and-set |
| Auth seam | One `authorizeManagement(req, op)` function returning allow; public by deployment policy through phase 3 |

### Verified platform facts (2026-09-30, disposable val `plusjade/managed-source-spike`)

- `sqlite.batch` rolls back earlier writes when a later statement violates a constraint.
- Ten concurrent batches inserting the same `publications.revision` produced exactly one
  commit, and its event write matched the winning revision.
- Observed latency from a val: ~30 ms read, ~110 ms write batch.

Documented but not yet exercised, verify at pool prep: remix copies files, env var
keys, and schema but not data by default; each remix has its own SQLite. Branches share
storage, so disposable tests use a separate slot, never a branch.

## Topology

```text
Agent ──POST /managed-sources──▶ managed-sources (provisioner, pool table)
                                   └─POST /manage/v1/initialize──▶ managed-source-NN
Agent ──GET/POST /manage/v1/*──────────────────────────────────▶ managed-source-NN (events, intent, receipts)
Parent ──GET / (canonical, unchanged)──────────────────────────▶ managed-source-NN
Human ──/feeds/:id/manage attach──▶ parent          iOS widget ──▶ parent /feeds/:id
```

The provisioner holds no parent authority and no Val Town credentials. It writes only
its own `pool` table and calls slot `initialize` over public HTTP.

## Pool preparation (operator, ahead of demand)

Per slot, once:

1. Remix `managed-source-template` to `managed-source-NN`. Set `source.json` key
   `managed-NN`, name "Managed source NN", `dataMode: "static"` (content is agent-published),
   freshness "Published by managing agents; no refresh schedule".
2. Run the public verifier against the slot endpoint (empty items pass).
3. Register and probe it in the parent per get-sources. Record the parent source ID.
4. Insert `{slot, val, endpoint, parentSourceId, state:'available'}` into the provisioner.

A slot key names a slot, not a purpose. Because a claimed slot is never reassigned,
each key still maps to exactly one purpose for life. The parent registry shows
"Managed source NN"; the steerer's name lives in source state (see Gaps).

## Journey A: bootstrap

Steerer: "Send these boxing findings to Clark View, and keep it updated when this
task runs." The agent reads the creation guide once (`GET /` on the provisioner; skip
if the prompt already contains it) and makes one call.

```http
POST https://<provisioner>/managed-sources
{
  "requestId": "boxing-bootstrap-7f3c",
  "name": "Major boxing",
  "intent": "Major upcoming boxing cards. mainText: 'A vs B'. subText: broadcast/PPV. Assume a 4-hour window from main-card start.",
  "agentLabel": "claude-scheduled-task",
  "events": [
    { "id": "boxrec-1234567", "mainText": "Usyk vs Dubois", "subText": "DAZN PPV",
      "startsAt": "2027-02-14T20:00:00-05:00", "expiresAt": "2027-02-15T00:00:00-05:00" }
  ]
}
```

```http
201 Created
{
  "operation": { "requestId": "boxing-bootstrap-7f3c", "state": "ready" },
  "source": {
    "name": "Major boxing",
    "slot": "managed-03",
    "manageUrl": "https://<slot-03>/manage/v1/state",
    "feedUrl": "https://<slot-03>/"
  },
  "receipt": { "requestId": "boxing-bootstrap-7f3c", "revision": 1, "changed": true,
    "intentChanged": true, "created": ["boxrec-1234567"], "updated": [], "removed": [],
    "unchanged": [], "alreadyAbsent": [], "committedAt": "2026-10-01T17:02:11Z" },
  "destination": {
    "integration": "registered_not_attached",
    "parentSourceId": 12,
    "parentSourceUrl": "https://<parent>/sources/12",
    "nextStep": "A Clark View admin attaches 'Managed source 03' to a feed at https://<parent>/feeds/manage. The events then appear in any widget showing that feed after its next refresh.",
    "notices": [
      "Public prototype: anyone with manageUrl can read and change this source.",
      "Changes affect every feed that includes this source and everyone viewing those feeds."
    ]
  }
}
```

The agent then updates its **existing** recurring task (if the host supports that)
with the `manageUrl` and publication rule, and reports: one event published; the
task was / was not updated; the feed attach is pending a human.

| Case | Behavior |
| --- | --- |
| Replay, same body | Returns the stored response (200, `"replayed": true`). No second slot, no republish |
| Same `requestId`, different body | 409 `request_id_reused`; the original creation stands |
| Invalid events/intent | 422 with all field errors; slot is released, nothing persists |
| Empty `events` | Allowed; revision 1 carries name and intent only |
| Slot initialize timed out or 5xx | 202 `{operation:{state:"pending"}, retryAfterSeconds:5}`. Retry the identical request; the provisioner re-drives the **same** slot, whose initialize is idempotent by `requestId` |
| Slot already initialized by someone else | Provisioner marks it `foreign` and tries the next slot (bounded by pool size) |
| No available slot | 503 `pool_exhausted`: "No managed-source capacity. Ask the Clark View operator to add slots." Nothing allocated |

A source is `ready` only after its slot commits revision 1. `pending` never reports
events as published.

Provisioner claim is one statement:
`UPDATE pool SET state='claiming', request_id=?, payload_hash=? WHERE slot=(SELECT slot FROM pool WHERE state='available' ORDER BY slot LIMIT 1)`,
preceded by a `request_id` lookup for replay. `request_id` is `UNIQUE`.

## Journey B: curate ("Fever first")

Steerer to a different agent: "Use https://<slot-05>/manage/v1/state. Make Fever
appear first: 'Fever at X' when away, 'Fever vs X' when home."

**Call 1** — `GET /manage/v1/state`

```json
{
  "source": { "name": "Indiana Fever games", "slot": "managed-05", "revision": 12,
    "intent": "Indiana Fever regular-season games. Opponent listed as 'Home vs Away'. Broadcast in subText. 2.5-hour window." },
  "scope": { "view": "current", "rule": "expiresAt after now − 24h, by startsAt", "returned": 3,
    "totalStored": 41, "truncated": false, "next": null, "all": "/manage/v1/state?view=all" },
  "events": [
    { "id": "wnba-401736201", "mainText": "Fever vs Sky", "subText": "ION", "startsAt": "2027-05-15T23:00:00Z", "expiresAt": "2027-05-16T01:30:00Z" },
    { "id": "wnba-401736214", "mainText": "Aces vs Fever", "subText": "ESPN", "startsAt": "2027-05-18T02:00:00Z", "expiresAt": "2027-05-18T04:30:00Z" },
    { "id": "wnba-401736230", "mainText": "Fever vs Liberty", "subText": "Prime", "startsAt": "2027-05-21T23:30:00Z", "expiresAt": "2027-05-22T02:00:00Z" }
  ],
  "guide": "<inline publication guide, below>"
}
```

**Call 2** — `POST /manage/v1/reconcile`

```json
{
  "requestId": "fever-first-2c91",
  "baseRevision": 12,
  "intent": "Indiana Fever regular-season games. Fever first: 'Fever vs X' at home, 'Fever at X' away. Broadcast in subText. 2.5-hour window.",
  "upserts": [
    { "id": "wnba-401736214", "mainText": "Fever at Aces", "subText": "ESPN", "startsAt": "2027-05-18T02:00:00Z", "expiresAt": "2027-05-18T04:30:00Z" }
  ],
  "removals": []
}
```

```json
{ "requestId": "fever-first-2c91", "revision": 13, "changed": true, "intentChanged": true,
  "created": [], "updated": ["wnba-401736214"], "removed": [], "unchanged": [], "alreadyAbsent": [],
  "committedAt": "2026-10-01T18:40:03Z" }
```

Only the away game changes wording; the home games already read "Fever vs X". Older
stored events outside the current view keep their old wording; the agent mentions that
and offers `?view=all` if the steerer wants them rewritten. The next scheduled run
reads the new intent in call 1 and follows it.

## Management API (per slot)

All routes return JSON with `Cache-Control: no-store`. Every route passes through
`authorizeManagement`. `GET /` and non-GET on `/` keep the canonical behavior.

| Route | Purpose |
| --- | --- |
| `GET /manage/v1/state[?view=current\|all&cursor=]` | Identity, intent, revision, scoped events, inline guide |
| `POST /manage/v1/reconcile` | Atomic intent + event publication |
| `GET /manage/v1/history[?limit=20]` | Optional: recent revisions with request ID, time, agent label, changed IDs |
| `POST /manage/v1/initialize` | Provisioner-only by convention: sets name, intent, initial events at revision 1 |

Before initialize, `state`/`reconcile` return 409 `not_initialized`; `GET /` returns empty items.

### Reconcile request

| Field | Rule |
| --- | --- |
| `requestId` | Required. `^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$`. New ID per distinct payload |
| `baseRevision` | Required integer: the `revision` last read |
| `intent` | Optional string, 1–1000 chars after trim. Omitted = unchanged |
| `agentLabel` | Optional, ≤ 64 chars; stored as unverified |
| `upserts` | Array of complete events, may be empty |
| `removals` | Array of event IDs, may be empty |

Event: `id` (same pattern as `requestId`), `mainText` 1–120 chars, `subText` 0–200 chars,
`startsAt`, `expiresAt`. Unknown fields are rejected.

Limits: body ≤ 256 KiB; `upserts` + `removals` ≤ 200; ≤ 1000 stored events per source
(exceeding returns 422 `source_full` with a suggestion to remove expired events).

### Timestamps

Accepted: `YYYY-MM-DDTHH:MM:SSZ` or `YYYY-MM-DDTHH:MM:SS±HH:MM`, with an optional
all-zero fraction. Rejected with an example: missing offset, date-only, non-zero
fraction, numbers. Stored as Unix seconds; returned as UTC `Z`. After normalization
the canonical window rule applies: `expiresAt > startsAt`, span ≤ 30 days.

### Semantics

- Upserts replace whole events by ID. Omitted events survive. Removing an absent ID
  is reported in `alreadyAbsent`. An ID in both lists or twice in either is a 422.
- Order: replay lookup → validation → `baseRevision` check → diff → commit.
  - Stored `requestId` with identical payload hash: 200 original receipt, `"replayed": true`,
    even if the revision has since moved.
  - Stored `requestId` with a different hash: 409 `request_id_reused`, stating the
    original publication is committed and unaffected.
- Stale `baseRevision`: 409 `stale_revision` with the current revision and current-view
  events in the body, so recovery needs no extra read.
- No effective change: 200 receipt with `changed:false`, unchanged revision, no history row.
  Its receipt is still stored for replay.
- Commit is one batch: event upserts/deletes, `meta` intent+revision, a `publications`
  row (revision PK = compare-and-set; carries before/after snapshots of touched events
  and intent for operator recovery), and the `receipts` row. Invalid requests write nothing.
- Receipts and publications are kept for the prototype's lifetime.

### Serving and management views

- Canonical `GET /` serves stored events with `expiresAt > now − 24h`, ordered by
  `startsAt` then `id`, first 500. Unchanged `{sourceKey, items}` schema; no management fields.
- `view=current` (default) is the same selection, 100 per page, with `next` cursor.
  `view=all` pages all stored events by `startsAt`. Every response states `totalStored`
  and `truncated`; omission from a view never means deletion.
- Nothing is deleted except by explicit removal.

### Errors and recovery

```json
422 {
  "ok": false, "error": "validation_failed",
  "errors": [
    { "path": "upserts[0].startsAt", "code": "missing_offset",
      "message": "Time must include Z or an offset.", "received": "2027-05-18T19:00:00",
      "example": "2027-05-18T19:00:00-04:00" },
    { "path": "upserts[1]", "code": "duplicate_id", "message": "wnba-401736214 appears twice." }
  ],
  "retry": "Fix all listed fields and resubmit with a new requestId. Nothing was changed."
}
```

| Status | Agent action |
| --- | --- |
| 400/422 | Repair every listed field; new `requestId`; one attempt |
| 409 `stale_revision` | Re-evaluate against the returned state; new `requestId`; at most 2 cycles |
| 409 `request_id_reused` | Original is committed; do not treat as failure |
| 429 | Honor `Retry-After` |
| Timeout / 5xx | Retry identical body and ID: 3 attempts, 1 s then 4 s. Absence of a response is not absence of a commit |

After the budget, report the blocker; existing data is untouched. Errors never carry
stack traces.

## Destination and path to a widget

1. Creation returns `parentSourceUrl` and `nextStep` (above). `integration` is the
   provisioner's static knowledge: `registered_not_attached`. It never claims attachment.
2. A person with parent browser access opens `/feeds/:id/manage` for the agreed shared
   UAT feed and attaches "Managed source NN" as Live. One form action; existing route.
3. In the app, the steerer joins that feed if needed and selects it in the widget
   editor. Existing paths. Items appear after the widget's next timeline reload.

No parent change is required. Authority for registration, attachment, subscription,
and widget selection stays in the parent and app.

## Agent guidance package

**Bootstrap prompt**

> Add Clark View as a destination for these findings using
> https://&lt;provisioner&gt;/managed-sources (read its guide at the same host's root).
> Reuse this conversation's research and preferences. Create the source and publish the
> usable events. [If recurring: update this existing task to maintain that destination
> on future runs.] Return the destination and say what was actually published and configured.

**Existing-source prompt**

> Use &lt;manageUrl&gt; to read this source and [requested change]. Preserve event IDs.
> Treat its shared preferences as defaults that my request can revise; publish updated
> preferences and affected events together when appropriate.

**Guide** (served at the provisioner root and inline as `guide` in state; one text):

> Clark View shows timed events in an iOS widget. You publish; you do not research here.
>
> - Create once: POST /managed-sources with requestId, name, intent, events. Retrying the
>   same body is safe. Keep the returned manageUrl.
> - Update: GET manageUrl, then POST …/reconcile with baseRevision from that read. Send
>   only changed events; omitted events stay. Remove by ID. Include `intent` only to change it.
> - Events: stable `id` (upstream ID if any; never derived from title or time), mainText,
>   subText, startsAt and expiresAt with an offset or Z. Skip events without a known start.
>   Estimate expiresAt from the intent's duration. Cancellation = removal.
> - Intent is the shared default wording and scope. The steerer's current request may revise
>   it; publish the new intent and the events it affects together.
> - Receipt = durably published. It does not mean the event is in a feed or a widget has refreshed.
> - Retries: timeout/5xx → same body and requestId; 422 → fix all errors, new requestId;
>   409 stale → re-evaluate against returned state, new requestId.
> - No new findings → publish nothing. Never clear a source because a run found nothing.
> - If you cannot make HTTP POST requests or update a schedule, say so; do not claim success.
> - Public prototype: anyone with this URL can edit; changes reach everyone using the feed.

## Gaps and deferred choices

- **Registry name is the slot name.** The steerer's source name is not shown in the
  parent or feed details. Closing it requires a parent change (read managed name at
  probe time or on attach); defer until UAT shows it matters.
- **Slot initialize is public.** Anyone can initialize an available slot directly; the
  provisioner skips such slots. Closed in phase 4 with provisioning authority.
- **Source rename** is not supported after creation.
- **Attachment is manual.** Acceptable for one shared UAT feed; revisit after phase 3.
- The spike val `plusjade/managed-source-spike` should be deleted after review.

## Phase 2 verification plan

- Slot template: canonical verifier pass; a scripted run covering create, replay,
  reuse conflict, stale conflict, validation repair, no-op, and concurrent publications.
- Provisioner: exhaustion, pending/re-drive, 422 release.
- Real agents: Journey A and B in two hosts where available; record calls, repairs,
  user questions, latency.
