# Clark View iOS widget implementation

The widget and app side of Clark View: file roles, Beacon behavior, refresh,
deep links, and push entitlement. The server contracts these
render are in [valtown-brief.md](valtown-brief.md). Route new information by
[AGENTS.md](../AGENTS.md#documenting-decisions).

The standalone Live Activity spike is separate from the temporal widget feed.
It uses parent `live_activity_spikes` records with presentation snapshots and
ActivityKit update/end pushes, without source/event references. Native diagnostics
creates the record before a foreground ActivityKit start and acknowledges success in
the app. Ordinary updates are quiet; an explicit alerting update asks iOS to briefly
expand the Dynamic Island. The alert intent is persisted for delivery retry. See
[live-activity-spike.md](live-activity-spike.md) for the iOS contract, operation,
and deployment status; parent `docs/live-activity-spike.md` owns its JSON routes
and SQLite schema. No browser UI or event scheduling is part of the spike.

| Local file | Role |
| --- | --- |
| [ServerURL.swift](../Shared/ServerURL.swift), [EventsClient.swift](../Shared/EventsClient.swift) | Base URL, device-row cache, and the events client used by widgets and view previews |
| [WidgetSelection.swift](../Shared/WidgetSelection.swift) | What a placement shows: selector precedence, the one query sent, and prompt states |
| [Feed.swift](../Shared/Feed.swift) | Legacy public feed client for feeds joined in earlier versions |
| [WidgetPayload.swift](../Shared/WidgetPayload.swift), [WidgetPresentation.swift](../Shared/WidgetPresentation.swift) | Wire decoding and presentation fallback |
| [BeaconDateTimeView.swift](../Shared/BeaconDateTimeView.swift) | Shared widget/app lifecycle date line and local day label |
| [ClarkViewWidget.swift](../ClarkViewWidget/ClarkViewWidget.swift), [WidgetFeedIntent.swift](../Shared/WidgetFeedIntent.swift) | Widget configuration (All my views, Selected views, retained feed), fetch, preview fixtures, timeline, entry view |
| [WidgetListCatalog.swift](../Shared/WidgetListCatalog.swift), [WidgetFeedCatalog.swift](../Shared/WidgetFeedCatalog.swift) | App Group picker choices and remembered names: joined views, and separately the legacy feeds |
| [BeaconWidgetTemplate.swift](../ClarkViewWidget/BeaconWidgetTemplate.swift) | Default widget layout and event deep links |
| [ContentView.swift](../clark_view/ContentView.swift), [MyListsView.swift](../clark_view/MyListsView.swift), `clark_view/List*.swift`, [FeedPreviewView.swift](../clark_view/FeedPreviewView.swift) | My views, directory and pre-join preview, reminder switch, and leave |
| `clark_view/Subscription*.swift`, [FeedSourcesView.swift](../clark_view/FeedSourcesView.swift) | Compatibility screens for feeds joined in earlier versions (Earlier feeds) |
| [AppDeepLink.swift](../Shared/AppDeepLink.swift), [DeepLinkRouter.swift](../clark_view/DeepLinkRouter.swift) | `clarkview` subject routes shared by widgets, Live Activities, alert responses, and in-app navigation |
| [DeviceIdentity.swift](../Shared/DeviceIdentity.swift), [DeviceStatusClient.swift](../Shared/DeviceStatusClient.swift) | Per-install UUID in `group.plusjade.clark-view`, self-registration, and diagnostic reads |
| [PushTokenClient.swift](../Shared/PushTokenClient.swift), [ClarkViewWidgetPushHandler.swift](../ClarkViewWidget/ClarkViewWidgetPushHandler.swift) | Native widget token upload/removal |
| [WidgetInventory.swift](../Shared/WidgetInventory.swift), [WidgetInventoryReporter.swift](../Shared/WidgetInventoryReporter.swift) | Widget inventory snapshot, upload policy, and coalesced reporter |
| [WidgetRefreshDiagnostics.swift](../Shared/WidgetRefreshDiagnostics.swift), [WidgetDiagnosticsView.swift](../clark_view/WidgetDiagnosticsView.swift) | Last manual request, network attempt, success/failure and app reload controls |

Beacon small/medium show the first item; large shows the first two. Medium and large order event
information as main text, subtext, then date/time. Their subtext uses the primary color in italic
monospace with a two-line limit. Small omits subtext and orders main text before its trailing,
stacked date and time or lifecycle label. All use the root surface directly. Large renders two
static, edge-anchored event regions without card surfaces or borders. A full-width rule separates
the events, and either event opens its own detail deep link. The first keeps its ideal height when
the pair overflows; the second compresses and truncates to fit the remaining space.
Ordinary
network/decoding failure currently returns an empty payload, not stale cached content
— distinguish failed fetches from successful empty feeds in diagnostics. Beacon has no
refresh button; manual refresh lives in the app only. Reload requests ask WidgetKit
for a timeline and do not guarantee immediate execution; the normal timeline requests
an hourly refresh. Native accented/vibrant appearances remain system-owned; Beacon respects
Reduce Motion and Reduce Transparency. WidgetKit gallery snapshots use offline event fixtures
without presentation overrides, so they render on neutral default surfaces; configured timelines
still honor server-provided root colors. Consult Swift for geometry, not this file.

The app home screen is My views. Product copy uses “views”; Swift types, saved
intent parameters, App Group keys, and API paths retain their existing names.
On first launch the install creates its own
device row (`POST /devices`). Views can be browsed and previewed before joining.
A join starts with Reminders off; the switch can be changed later, and Leave view
removes this device's membership. A view owns its reminder timing. After a join or
leave the app asks WidgetKit to reload, since widgets showing All my views follow
membership; WidgetKit decides when that runs.

Human view links use the parent's `/open/views/:id` landing page and
`clarkview://view/<id>`. `IncomingListView` resolves the numeric ID through
`ListClient.detail`; links carry no title or management endpoint. An unjoined view
opens its preview with an explicit Join, while a joined view opens its detail.
Opening a link never changes membership or reminder preferences.

`ListDetailView` offers **Copy editing instructions** when the parent advertises
management version 2 and its state URL. The preferred agent reads current state
and guidance there; copied text contains no device identity or token. Changes to
view metadata and events affect everyone joined, whereas the reminder toggle and
Leave remain device-specific. Computed views without this capability omit the action.

The one registered Clark View widget kind (`ClarkViewWidgetConfigurable`) is configurable
for home and lock screens, and `WidgetFeedIntent` keeps its type name and `feed` parameter
because those are the saved identity of existing placements. Its editor has **Show**
(All my views or Selected views) and, for Selected, **Views**. `WidgetSelection` resolves
a placement in this order: an explicit mode, otherwise a retained `feed`, otherwise All.
`mode` has no default so that an upgraded placement's saved feed is not overridden by a
decoded value; a new placement has nothing saved and shows All my views.

- All never stores view IDs. The server resolves membership on every fetch, so a
  server-side membership change reaches the widget without opening the app.
- Selected stores view IDs. An ID that is no longer joined contributes nothing and
  becomes eligible again on rejoin; the app never rewrites a stored selection.
- A retained feed is sent as `feedId` to the same events route. The server translates it;
  the client never treats a feed ID as a view ID. Choosing a mode supersedes it, and only
  the effective selector is sent. The retained feed is offered in the editor only while it
  is the effective selection.
- The picker reads the App Group view catalog, which the app replaces after each successful
  membership load and updates after joins and leaves. Failed loads keep the last snapshot,
  and configuration queries make no network requests. Open the app after a server-side
  rename to refresh names. Remembered names outlive membership.
- The legacy feed catalog is separate and is never overwritten by the view catalog. The app
  still refreshes it on activation so retained feed selections resolve their names.

Every placement reads `/devices/:id/events`. The widget resolves the device row with the
idempotent `POST /devices` and caches it in the App Group, so an upgraded placement works
before the app is next opened. A `device_not_found` response clears the cache and
re-resolves once, because a browser merge moves an installation to another row.

Prompt states come from the server's `selection.listIds`, never from a failure:

| State | Shows |
| --- | --- |
| Selected with no views chosen | Edit Widget prompt; no request is made |
| All, nothing joined | Invitation to join a view in the app |
| Selected, none of the chosen views joined | Edit Widget prompt; never falls back to All |
| Retained feed no longer exists | Feed unavailable; edit to choose views |
| Views resolved but no events, or a failed fetch | The ordinary empty state |

A network or identity failure never changes a stored mode or selection. The app's manual
widget refresh control still requests a timeline reload. The app reuses the widget's date
line, refreshes when opened or foregrounded, and supports pull to refresh. Notification
setup and its diagnostics live under the toolbar menu's Notifications entry.

Legacy feeds appear under **Feeds from earlier versions** on the home screen
when any exist. That screen lists them, shows whether reminders are on, and can turn a
reminder off or leave the feed. Their reminders keep arriving until turned off there.
The original lists rollout started membership empty; nothing was imported from
legacy feeds. Renaming the product to views preserves all existing memberships.

Widget inventory is reported from `Provider.timeline` (including unconfigured paths),
app activation, and successful registration — never from placeholders,
snapshots, or rendering. It uploads `WidgetCenter.currentConfigurations()` only when the
normalized contents changed, nothing has succeeded, or the last success is 24 hours old;
a failure waits five minutes before the next natural trigger retries (registration bypasses the
wait). The timeline awaits the reporter alongside the feed fetch; the reporter bounds
itself to three seconds and never fails the timeline. A failed configuration query is not
uploaded as an empty inventory. Each entry reports its mode: `all`, `selected` with view IDs,
or `feed` with the retained feed ID; Selected with no views reports as unconfigured. Event
reads send installation, caller, family, and purpose headers for server receipts. Reports can lag: removing the last widget runs no timeline,
so it appears only after the app is next opened. Placements have no stable identity.
Parent `docs/widget-inventory.md` owns the server contract.

Widget and Live Activity taps carry their displayed snapshot through the app-owned
`clarkview` URL scheme and push a native detail destination. Each large-widget event
opens its own detail directly; the widget has no local expand/collapse state.
The route is presentation-only and performs no mutation or server lookup.

### Widget configuration verification (2026-09-24)

Manual testing of the prior configurable build confirmed that widgets retained
individually assigned feeds. This change keeps the configurable kind and `feed`
intent parameter. The app/widget build and existing iOS tests passed during this
change. Its feed-picker smoke test was blocked by an ad hoc simulator build without
a team identity. As of 2026-10-02, this is historical legacy coverage: the new-list
handoff and widget delivery are accepted below. Feed-picker and multiple-placement
combinations are deferred to scoped compatibility work, not an active test hold.

### Widget inventory verification (2026-09-25)

Server additions are live on parent `main` version 402 and `tools/check.ts` passes.
The app/widget build and full test scheme passed with no new SwiftLint warnings.
Deferred coverage as of 2026-10-02: register, close the app, add a configured widget, and confirm
`/devices/:id/widgets` shows it without reopening the app, including whether configurations are readable during the initial
timeline callback. Widget rendering acceptance alone does not establish this
telemetry timing. Revisit when inventory behavior or the device migration is in scope.

The widget extension owns its push entitlement and `.pushHandler`. The containing app
separately requests visible-notification permission, registers an app token, and
uploads it with the last observed alert permission to
`/device/notifications/register`. See [push-notifications.md](push-notifications.md)
for setup, the token/topic contract, and current verification status — don't restate
those facts here.

## Deferred compatibility and expanded UX checks

Dated records below retain the term “lists” used during those releases. For future
manual checks, the same controls now read My views, All my views and Selected views;
the rename preserves membership and widget selection.

Status reviewed 2026-10-02: the managed-list milestone is accepted below. The older
checks in this section are retained for future change-specific or legacy-cutover
work, not as holds on managed-source iteration. Unobserved combinations are not
being declared passed. Do not run this matrix or migrate devices without the next
user-prescribed scope.

### Legacy navigation record (2026-09-26)

The old bottom Join Feed flow has been superseded by My lists and the explicit
list Join flow. Its prior simulator navigation blockage is no longer an active
acceptance task. Diagnostics, notification-warning shortcuts, VoiceOver, large
text and iPad combinations were not established by that test; evaluate them when
those surfaces change. Current owners are `ContentView.swift`, `DiagnosticsPanel.swift`
and the list views, rather than the retired bottom-toolbar journey.

### Local widget picker acceptance (2026-09-29)

The network-backed last-joined default was retired after the earlier A-then-B
placement test selected stale A and the user reported intermittent two-tap picker
opening. Configuration queries now read only the local catalog; this removes their
network dependency but does not establish that the iOS presentation symptom is fixed.
See `Shared/WidgetFeedIntent.swift` and `Shared/WidgetFeedCatalog.swift`.

Superseded 2026-10-01 before it was run: the editor now selects lists, not a feed.
The unresolved first-tap picker presentation and offline picker checks carry into
Lists acceptance below, against the Lists picker.

### Lists acceptance (2026-10-01)

Server routes are live on parent `main` version 452 and `tools/check.ts` passes. The
app/widget build and full test scheme pass with SwiftLint at its prior warning count. On an
iOS 26.5 simulator the app's browse, preview, join, detail, and leave flow passed against
the live server. Evidence: `clark_viewTests/WidgetSelectionTests.swift` for selector
precedence and prompts; parent `docs/lists.md` for the contract.

Observed 2026-10-01T21:51Z on parent device 7, a team-signed install updated to this
build: its four existing placements (medium, large, two lock-screen) reported
`mode:"feed"` with their saved feed IDs and read the events route as `feed:2` and `feed:3`
with 200s, with no list memberships. Evidence: `/devices/7/views`. That establishes the
retained selection and the bridge on a real upgrade. It does not establish that this
happens before the app is first opened, or what the widgets displayed.

Deferred compatibility/picker scenarios, not closed by the managed-list UAT:

1. Confirm an upgraded feed widget refreshes before the app is first opened, and that it
   renders its events with the global appearance.
2. Edit that placement: the editor shows Show plus the retained feed. Choose All my lists,
   then Selected lists; each uses the events route with the new selector and no `feedId`.
   Confirm the conditional editor rows (`parameterSummary`) behave as described above.
3. Add a new placement: it starts on All my lists with no feed picker.
4. Selected with only list A, then leave A in the app: the widget asks for an edit rather
   than showing All; rejoin A and it returns.
5. The Lists picker opens on the first tap, and still opens offline from the last catalog.

Reassess these scenarios when the user scopes the prototype-device migration;
retire obsolete cases explicitly rather than requiring old flows to pass before
cleanup. Lock-screen placements, large text, VoiceOver, multiple widgets, the
Feeds from earlier versions screen and real-device reminder delivery remain
unclaimed coverage, not blockers to the accepted public managed-source milestone.

### Managed-list handoff acceptance — closed 2026-10-02

The user verified opening and joining on iPhone, copying instructions from the app
into an agent to edit the same list, and widget display of published changes after
refresh. Agent bootstrap/curation and friendly-domain publication were previously
accepted. Continuity is accepted within a simulated time-frame; see
[managed-source-plan.md](managed-source-plan.md) for the consolidated evidence and
scope limits. No human-handoff or delivery UAT hold remains for this milestone.

Implementation owners are `IncomingListView`, `ListDetailView`, and parent
`docs/lists.md`. Reopening while already joined, cold-launch/Diagnostics combinations,
computed-list action visibility, accessibility and cross-agent variations remain
optional change-specific checks; the user's acceptance is not a claim that every
combination was exercised. WidgetKit still controls when a requested refresh occurs.
