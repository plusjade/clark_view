# Lists: additive execution plan

Status: implemented 2026-10-01; server deployed on parent `main` version 452, native
client built and tested but not released. Open: the team-signed widget acceptance in
[ios-widget.md](ios-widget.md#lists-acceptance-2026-10-01) and real-device reminder delivery
(manual acceptance item 5 below). Current contracts live in valtown-brief.md, ios-widget.md, and
parent `docs/lists.md`; this document remains as the scope and manual acceptance record.
Close it when the open items pass.

## Outcome and scope

Make a source directly usable as a **list**. A device joins lists, independently
enables reminders, and displays events from all joined lists by default. Additional
widgets can select a subset. No mandatory feed creation or managed group exists in
the new experience. Use Lists, Events, All my lists, Selected lists, and Reminders
in new user-facing interfaces. Existing internal source/feed names may remain.

This is greenfield alongside legacy, not a destructive conversion. Add interfaces
and membership storage; project existing source registry rows as lists. Reuse pure
composition, validation, token delivery, and event identity infrastructure. Do not
duplicate source data or reinterpret feed IDs as source IDs. Do not rename the
repository broadly, implement saved groups, add authentication, change source
protocols, or build a new source-authoring system as part of this work.

## Compatibility boundary

- Existing app builds keep their routes, payloads, feed membership, and behavior.
  Preserve legacy feeds, assignments, subscriptions, presentation data, and reminder
  timing while those clients remain supported.
- Updated containing apps enter the new lists experience. New list memberships
  start empty; do not silently expand/import legacy subscriptions, dual-write
  membership, or mutate legacy joins. Reuse the registered device identity.
- Existing widget placements keep their saved selection after an app update, but
  run the updated provider and use the same greenfield events route as new
  placements. Retain widget kind `ClarkViewWidgetConfigurable`, WidgetFeedIntent,
  its legacy `feed` parameter and entity identity; evolve the intent compatibly.
  Do not add a separate lists widget kind or require users to replace placements.
- Send a retained feed entity ID as `feedId` to the new route. The server translates
  its enabled source assignments into list IDs, then uses the common composition
  path. Do not translate on the client, treat a feed ID as a list ID, or import
  membership. Unupdated binaries continue using the old routes until retirement.
- New placements default to All my lists. Existing placements can explicitly
  switch to All or Selected lists through Edit Widget without removal/re-addition.
  Verify compatible intent decoding and this transition on a team-signed device.
- Retain legacy entity resolution and a bounded way to refresh its catalog in the
  updated app; do not overwrite its App Group storage with the new list catalog.
- Legacy reminders may still be enabled after update. Provide a clearly labeled
  compatibility management path to inspect and turn them off/leave old feeds.
  Do not silently strand or disable them. This is separate from new list membership.

## Data and ownership

1. A list ID is the opaque string representation of an existing source registry ID.
   Names remain editable labels. Preserve `<source-id>:<local-item-id>` event IDs.
2. Add `sources.reminder_lead_seconds INTEGER NOT NULL DEFAULT 3600` using an
   additive, idempotent migration. All existing sources begin at 3600; do not infer
   timing from feeds or copy the 86400 outlier. Keep the database default for future
   inserts. Do not rebuild sources and risk cascading assignment deletion.
3. The new reminder path reads timing from sources only. Retain legacy feed timing
   for old consumers; moving ownership in the new model does not authorize changing
   old subscription semantics. No timing editor or per-device override is needed.
4. Add a device/list membership table with a unique device/source pair, foreign
   keys, reminders-enabled default false, and timestamps using the parent's UTC
   convention. Reuse registered devices. No priority, presentation, assignment
   enabled state, or copied reminder lead belongs in this table.
5. Preserve source conformance eligibility and pointer ownership. Joining a list
   does not bypass verification, and clients cannot supply source endpoints.

## New HTTP contracts

Finalize exact response types alongside their first callers; the required semantics
below are fixed. New browser pages and JSON routes must have unambiguous negotiation.

| Route | Contract |
| --- | --- |
| GET /lists | Directory projecting source identity and reminder lead, with availability sufficient to explain ineligible lists |
| GET /lists/:id | List metadata for preview/detail; do not expose registry internals unnecessarily |
| GET /devices/:id/lists | Joined lists, independent reminder state, source-derived reminder lead, and delivery status needed by the app |
| PUT /devices/:id/lists/:listId | Idempotently join; a new membership starts with reminders off, a repeated join preserves preferences |
| PATCH /devices/:id/lists/:listId | Explicitly update reminder enabled state; missing membership is not an implicit join |
| DELETE /devices/:id/lists/:listId | Idempotently leave; revoke new-path reminder eligibility and inclusion in new widgets |
| GET /events?listIds=1,2,3 | Explicit public composition, used by previews before joining |
| GET /devices/:id/events | Compose all currently joined lists |
| GET /devices/:id/events?listIds=1,3 | Compose the intersection of selected IDs and current membership |
| GET /devices/:id/events?feedId=5 | Legacy selection bridge: translate the feed's current enabled source assignments into list IDs, then run common event composition |

Validate IDs, normalize duplicate selections, and bound requests. No selection
parameter on the device route means all; an empty or malformed parameter returns
400, never all. Public composition requires a nonempty selection and returns 404
for unknown IDs. Device composition requires a known device; stale selected IDs
no longer joined contribute nothing. A valid empty device collection or empty
intersection succeeds with an empty payload. Do not silently broaden a selection.

`feedId` and `listIds` are mutually exclusive; reject requests containing both,
duplicate selector parameters, or empty/malformed selectors with 400. An unknown
or deleted feed returns 404; a known empty feed succeeds. The legacy bridge resolves
assignments on every read and does not intersect them with new device memberships:
updated installs may have no new memberships, and preserving a saved feed selection
must not silently empty it. It creates no joins or reminder subscriptions. Resolve
All, Selected, and legacy-feed selectors into one internal list-selection shape
before validation, source reads, composition, and rendering metadata. Preserve
selector provenance for diagnostics; do not build a parallel legacy composer.

All widgets running the updated extension use `/devices/:id/events` and the same
native client/provider path. Ensure device identity resolution/registration can
complete for an upgraded placement even before the containing app is next opened;
do not treat temporarily unavailable identity as an empty collection or erase its
configuration. Old `/feeds/:id` routes remain for binaries that have not updated.

Use the current widget response envelope and item field names where compatible;
the route name does not require a wire rename. Preserve validation, temporal
sorting, quarantine diagnostics, timezone forwarding, and current failure policy.
Quarantined sources remain withheld; a read failure from an eligible source still
fails composition. Do not add partial-result behavior in this scope.

The parent resolves membership at request time. Cached app IDs supply picker
choices, not authoritative All my lists membership. Device identity now affects
selection on these explicit routes, unlike observational headers on legacy reads.
Keep responses no-store. Do not impose a silent five-list cap: include all joined
lists, subject to explicit request/resource bounds. Visible item counts remain a
layout concern; inclusion does not guarantee one visible event per list.

## Presentation freeze

New event responses use one code-owned global policy: Beacon, presentation v2,
white/light and black/dark roots, existing global lifecycle labels, and hide-expired
false (the documented current default). No per-list or per-feed presentation is
consulted by the new path, including requests bridged from `feedId`. Updated legacy
placements therefore adopt global appearance while retaining their source selection.
Do not add a settings UI or widget appearance controls
in this scope. Keep expiry filtering separate from reminder eligibility.

Freeze legacy presentation at the compatibility boundary: leave stored values and
legacy readers intact, and do not evolve them or import them into lists. Keep old
write contracts working where required by existing consumers; this freeze is not
permission to break an existing API. No normalization of old feed appearance is
required. A future global editor can replace the code-owned policy if needed.

## Agent-facing list publication and registration

This is a required delivery surface, not deferred terminology cleanup. Audit and
upgrade the existing agent instructions for adding a completed source to the
parent so the new journey ends with a directly usable list, without feed creation
or attachment. Preserve source authoring/protocol internals; this is a mechanical
adaptation of registration and its entry points, not a new provisioning system.

Audit (closed 2026-10-01): parent `docs/get-sources.md` required a bunch, wrote the
nonexistent `bunch_id`, and directed assignment through a device Sources view. It is
now "Publishing a list" and was exercised end to end with a disposable registration.
Owning paths: parent `docs/get-sources.md` (the procedure), parent `source/README.md`
(handoff), and `plusjade/source-template` `AGENTS.md` and README (completion wording).
No rendered browser page, app screen, or copied prompt serves the guide.
`plusjade/managed-sources` (`guide.ts`, README, and its `destination` states) was
reconciled separately on 2026-10-01; see the flag in
[managed-source-plan.md](managed-source-plan.md) for its states and open verification.

Required work:

- Trace browser/app entry points to that guide, including rendered help, copied
  prompts, linked Markdown, and registration completion messages. Audit linked
  template README/AGENTS guidance only where it describes parent registration or
  subsequent use. Record the actual owning paths in the implementation handoff;
  do not assume editing the Markdown changes every served/copied instruction.
- Update the canonical operator guide and new-facing labels to "list". Explicitly
  explain that the backing registry and source contract retain their legacy names.
  Remove obsolete bunch/device-assignment steps and replace mandatory feed
  attachment with availability through the new lists directory and event preview.
- Preserve deterministic manifest mapping, endpoint discovery from links.endpoint,
  explicit get-no-settings read_profile, exact-retry identity reuse, conflict
  handling, conformance reset on replacement, and parent-owned verification.
  A renamed concept must not weaken trust or give source authors parent access.
- New registration omits reminder_lead_seconds so the database supplies 3600;
  verify the returned value. An exact retry or pointer replacement must not reset
  an existing list's reminder preference. Do not copy feed lead values.
- Registration makes a list discoverable; it does not join a device or enable
  reminders. If the user's request also authorizes adding it to a particular
  device, use the new idempotent membership route after verification, with reminders
  initially off. Otherwise report it as available to join. Do not write legacy
  feed assignments or subscriptions as a hidden registration side effect.
- Completion guidance reports the stable list ID, verification result, usable
  preview/directory link, and whether device membership actually changed. Separate
  publication, verification, joining, and eventual widget refresh in success claims.
- Reconcile registration references in this repository's orientation and template
  pointers. Flag the older managed-source plan's feed/attachment assumptions where
  they intersect this flow; do not implement that separate roadmap in this change.

Acceptance gate: follow the actual app-linked/copied instructions with one scoped
disposable source/list. Confirm registry creation, parent verification, appearance
in /lists, event preview, 3600 lead, and (when authorized) a device join visible to
All my lists. Repeat registration to confirm the same ID and no duplicate membership
or reset preferences. Confirm no feed/bunch/legacy assignment was needed or written.
Clean up fixtures. Exercise the published entry point, not just the repository copy.
Run parent tools/check.ts for parent documentation or code changes; use each affected
val's prescribed checks if template guidance is changed. Retain legacy procedures
only when clearly labeled and still valid for a supported compatibility operation.

## Native app and widgets

- New home: My lists, directory/preview/join, independent reminders, and leave.
  Joining explains that the list appears in widgets showing All my lists.
- A new local App Group catalog holds joined list choices and remembered labels.
  Preserve it on failed refresh, update after successful membership mutations, and
  perform no network requests inside intent queries.
- Evolve the existing intent with an optional explicit All my lists / Selected
  lists mode and selected list IDs. Selection precedence is: explicit new mode,
  otherwise retained legacy `feed`, otherwise All. Keep absence of the new mode
  distinguishable from explicit All; a decoded default must not override a saved
  feed. All never stores an expanded ID snapshot. Selected stores stable IDs.
- Explicitly choosing a new mode supersedes any retained feed parameter; the
  client sends only the effective selector. Selected with no IDs shows an edit
  prompt and must not issue an unfiltered All request. Verify the editor supports
  this transition without requiring widget replacement.
- All mode reads the device events route. Selected mode passes its IDs to that
  route. Leaving removes a list from both modes on the next successful fetch.
  Rejoining a still-selected ID makes it eligible again; do not silently rewrite
  persistent widget selections based on transient catalog state.
- Empty All mode invites joining a list. Selected mode with no eligible selected
  lists asks to edit the widget, not to switch implicitly to All. Distinguish this
  from eligible lists that simply have no events; provide minimal response selection
  metadata if necessary to make that distinction reliably.
- Temporary network failures never change stored mode or selected IDs. Refresh
  requests remain best effort under WidgetKit scheduling.
- Extend inventory and request receipts additively to describe new modes/selections.
  Keep old feed observations valid; do not invent feed IDs for new compositions.
- Keep source-independent event deep links and current rendering unless required
  by the new flow. Registration must complete before device-scoped reads can work.

## Reminders and coexistence

Extend the builder/drainer to support new membership eligibility and source-owned
lead time without duplicating delivery infrastructure. Both paths must share the
existing event identity and terminal delivery ledger. Same-device, same-event,
same-lead overlap must not send twice. Legacy different-lead reminders can still
exist; the compatibility management path lets users turn them off.

Inspect queue ownership before editing: queued work must retain enough provenance
to revalidate the applicable membership and timing at drain time. Leaving or turning
reminders off invalidates that path's eligibility; another independently eligible
legacy/new path may still authorize delivery. Do not let one path cancel the other,
replay terminal rows, reset the ledger, or send real alerts as casual smoke tests.

## Implementation sequence and gates

1. Inspect current parent routes/stores, queue ownership, native intent/provider,
   inventory seams, and app-linked agent registration guidance. Record precise
   additive contracts, guidance entry-point owners, and recovery procedure.
   Preserve the parent's HTTP entry identity. Use one branch per affected val.
2. Add source timing and new membership schema with a recoverable snapshot and
   idempotent migrations. Verify legacy row/assignment preservation. Implement new
   list routes and shared composition adapters; no production membership backfill.
3. Add the new reminder path and coexistence semantics. Validate with delivery
   disabled and scoped fixtures, accounting for shared SQLite across branches.
4. Implement native list client/catalog/screens, legacy reminder management, and
   compatible evolution of the existing widget intent/provider. Move updated
   placements onto the common events route with the server-side feedId bridge.
   Validate installed-build upgrade/selector precedence early, then All and subset
   selection. Report platform blockers rather than silently introducing a distinct
   widget kind, requiring replacement, or substituting saved groups.
5. Extend diagnostics/inventory and complete one representative end-to-end flow.
   Upgrade and exercise the agent-facing registration surface described above;
   this is a completion gate, not a follow-up cleanup task.
   Deploy server additions before the native client. Legacy remains available as
   compatibility infrastructure, not an automatic data-conversion target.
6. Update current orientation/contracts in place and record significant decisions
   in CHANGELOG. Close this plan's status only when implementation and required
   verification are complete; keep deferred manual acceptance explicitly scoped.

Rollback must leave legacy functional without dropping new membership data. Disable
new reminder scheduling if needed while retaining its ledger. Do not use destructive
down migrations or replay completed migration/backfill operations.

## Verification and implementation handoff

Run parent `tools/check.ts` through run_file, and iOS `xcodebuild ... test` plus
`swiftlint lint`. Run a source val's own runner only if that source is actually
changed. Extend existing checks only for intentionally changed/new lasting seams,
following AGENTS.md; no test-per-edit expansion. Never read passing checks.

Verify changed deployed routes with scoped fixtures: membership/preferences,
all/subset composition, empty versus invalid selection, conformance, preserved
event IDs/order, legacy responses, and reminder deduplication/cancellation. Delete
disposable migration probes in the same change and record results in the commit.
Do not equate a successful empty payload with verified source contribution.
Verify the feedId bridge with enabled/disabled assignments, no new memberships,
unknown/empty feeds, ambiguous selectors, and the same global presentation and
composition behavior as explicit list selections. Confirm updated widgets use the
new route while an unupdated build still succeeds through the old route.

Manual acceptance plan (report passed, failed, blocked, and unrun separately):

1. Fresh device: join A and B, place a new default widget. It displays their
   chronologically composed events without requiring source selection. Reminders
   start off.
2. Add a Selected lists widget containing only A. Join C, then leave A. After
   refresh, All follows B/C; Selected requests a new selection. Rejoin A and verify
   its stored selection works again. Eligible lists with no events show an empty
   event state rather than an invalid-selection prompt.
3. Browser membership/rename change: refresh widget without first refreshing app;
   All uses current server membership. Open app to refresh picker names/choices.
   Picker still opens offline from its last successful catalog.
4. Upgrade a team-signed installation with an existing configured legacy widget:
   without re-adding it or first opening the app, confirm the placement retains its
   feed selection, requests the new events route with feedId, and adopts global
   presentation. New joins/leaves do not change that bridged selection. Edit the
   same placement to All, then Selected; confirm it uses the same route with the
   new selector and no feedId. Inspect and disable a legacy reminder through the
   compatibility path. Verify newly added placements start in All mode.
5. On authorized real-device notification testing, enable a list reminder and
   confirm one alert for an event also eligible through a legacy join at the same
   lead; turning off/leaving one path does not invalidate the other. APNs acceptance
   alone does not establish visible delivery.
6. Check empty membership, subset picker, large text/VoiceOver, and home/lock-screen
   placements. Distinguish successful builds from actual widget registration and
   upgrade acceptance. Leave broader combinations to manual testing per testing.md.

## Deferred cleanup

No legacy table/route/widget removal, broad source-to-list rename, feed presentation
rewrite, saved groups, per-user lead overrides, or data import UI. After adoption,
assess retirement using actual old-client and widget usage. There is no automatic
retirement date. Retain legacy configuration decoding and the feedId bridge until
usage supports retiring them; widget replacement is not the migration mechanism.
