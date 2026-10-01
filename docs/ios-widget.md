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
| [ServerURL.swift](../Shared/ServerURL.swift), [EventsClient.swift](../Shared/EventsClient.swift) | Base URL, device-row cache, and the events client used by widgets and list previews |
| [WidgetSelection.swift](../Shared/WidgetSelection.swift) | What a placement shows: selector precedence, the one query sent, and prompt states |
| [Feed.swift](../Shared/Feed.swift) | Legacy public feed client for feeds joined before lists |
| [WidgetPayload.swift](../Shared/WidgetPayload.swift), [WidgetPresentation.swift](../Shared/WidgetPresentation.swift) | Wire decoding and presentation fallback |
| [BeaconDateTimeView.swift](../Shared/BeaconDateTimeView.swift) | Shared widget/app lifecycle date line and local day label |
| [ClarkViewWidget.swift](../ClarkViewWidget/ClarkViewWidget.swift), [WidgetFeedIntent.swift](../Shared/WidgetFeedIntent.swift) | Widget configuration (All my lists, Selected lists, retained feed), fetch, preview fixtures, timeline, entry view |
| [WidgetListCatalog.swift](../Shared/WidgetListCatalog.swift), [WidgetFeedCatalog.swift](../Shared/WidgetFeedCatalog.swift) | App Group picker choices and remembered names: joined lists, and separately the legacy feeds |
| [BeaconWidgetTemplate.swift](../ClarkViewWidget/BeaconWidgetTemplate.swift) | Default widget layout and event deep links |
| [ContentView.swift](../clark_view/ContentView.swift), [MyListsView.swift](../clark_view/MyListsView.swift), `clark_view/List*.swift`, [FeedPreviewView.swift](../clark_view/FeedPreviewView.swift) | My lists, directory and pre-join preview, reminder switch, and leave |
| `clark_view/Subscription*.swift`, [FeedSourcesView.swift](../clark_view/FeedSourcesView.swift) | Compatibility screens for feeds joined before lists (Earlier feeds) |
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

The app home screen is My lists. On first launch the install creates its own
device row (`POST /devices`). Lists can be browsed and previewed before joining.
A join starts with Reminders off; the switch can be changed later, and Leave list
removes this device's membership. A list owns its reminder timing. After a join or
leave the app asks WidgetKit to reload, since widgets showing All my lists follow
membership; WidgetKit decides when that runs.

The one registered Clark View widget kind (`ClarkViewWidgetConfigurable`) is configurable
for home and lock screens, and `WidgetFeedIntent` keeps its type name and `feed` parameter
because those are the saved identity of existing placements. Its editor has **Show**
(All my lists or Selected lists) and, for Selected, **Lists**. `WidgetSelection` resolves
a placement in this order: an explicit mode, otherwise a retained `feed`, otherwise All.
`mode` has no default so that an upgraded placement's saved feed is not overridden by a
decoded value; a new placement has nothing saved and shows All my lists.

- All never stores list IDs. The server resolves membership on every fetch, so a
  browser-side membership change reaches the widget without opening the app.
- Selected stores list IDs. An ID that is no longer joined contributes nothing and
  becomes eligible again on rejoin; the app never rewrites a stored selection.
- A retained feed is sent as `feedId` to the same events route. The server translates it;
  the client never treats a feed ID as a list ID. Choosing a mode supersedes it, and only
  the effective selector is sent. The retained feed is offered in the editor only while it
  is the effective selection.
- The picker reads the App Group list catalog, which the app replaces after each successful
  membership load and updates after joins and leaves. Failed loads keep the last snapshot,
  and configuration queries make no network requests. Open the app after a browser-side
  rename to refresh names. Remembered names outlive membership.
- The legacy feed catalog is separate and is never overwritten by the list catalog. The app
  still refreshes it on activation so retained feed selections resolve their names.

Every placement reads `/devices/:id/events`. The widget resolves the device row with the
idempotent `POST /devices` and caches it in the App Group, so an upgraded placement works
before the app is next opened. A `device_not_found` response clears the cache and
re-resolves once, because a browser merge moves an installation to another row.

Prompt states come from the server's `selection.listIds`, never from a failure:

| State | Shows |
| --- | --- |
| Selected with no lists chosen | Edit Widget prompt; no request is made |
| All, nothing joined | Invitation to join a list in the app |
| Selected, none of the chosen lists joined | Edit Widget prompt; never falls back to All |
| Retained feed no longer exists | Feed unavailable; edit to choose lists |
| Lists resolved but no events, or a failed fetch | The ordinary empty state |

A network or identity failure never changes a stored mode or selection. The app's manual
widget refresh control still requests a timeline reload. The app reuses the widget's date
line, refreshes when opened or foregrounded, and supports pull to refresh. Notification
setup and its diagnostics live under the toolbar menu's Notifications entry.

Feeds joined before lists appear under **Feeds from earlier versions** on the home screen
when any exist. That screen lists them, shows whether reminders are on, and can turn a
reminder off or leave the feed. Their reminders keep arriving until turned off there.
List membership starts empty after an update; nothing is imported from those feeds.

Widget inventory is reported from `Provider.timeline` (including unconfigured paths),
app activation, and successful registration — never from placeholders,
snapshots, or rendering. It uploads `WidgetCenter.currentConfigurations()` only when the
normalized contents changed, nothing has succeeded, or the last success is 24 hours old;
a failure waits five minutes before the next natural trigger retries (registration bypasses the
wait). The timeline awaits the reporter alongside the feed fetch; the reporter bounds
itself to three seconds and never fails the timeline. A failed configuration query is not
uploaded as an empty inventory. Each entry reports its mode: `all`, `selected` with list IDs,
or `feed` with the retained feed ID; Selected with no lists reports as unconfigured. Event
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
change. The single-widget editor/render smoke test awaits a team-signed build:
the local simulator artifact is ad hoc signed with no team identity, so it cannot
reliably register the feed App Entity. Recheck one placement on a team-signed build.
Multiple-widget combinations and replacement of retired placements remain manual
acceptance checks.

### Widget inventory verification (2026-09-25)

Server additions are live on parent `main` version 402 and `tools/check.ts` passes.
The app/widget build and full test scheme pass with no new SwiftLint warnings. Pending
on a team-signed device: register, close the app, add a configured widget, and confirm
`/devices/:id/views` shows it without reopening the app, including whether configurations are readable during the initial
timeline callback. Close this status once that is observed.

The widget extension owns its push entitlement and `.pushHandler`. The containing app
separately requests visible-notification permission, registers an app token, and
uploads it with the last observed alert permission to
`/device/notifications/register`. See [push-notifications.md](push-notifications.md)
for setup, the token/topic contract, and current verification status — don't restate
those facts here.

## Pending navigation acceptance (2026-09-26)

The Diagnostics hub and bottom Join Feed toolbar in `ContentView.swift`,
`DiagnosticsPanel.swift`, and `SubscriptionListView.swift` still need interactive
acceptance. The iOS 26.5 Simulator build and test run passed, but the UI automation
bridge repeatedly returned error -10005 (invalid element ID) when selecting the
Simulator window, blocking the navigation smoke test. Close this status after
opening the stethoscope, entering a panel and returning to Diagnostics, dismissing
the sheet, and opening Join Feed from the bottom-right plus. Also verify the
notification-warning shortcut with a feed whose reminders are enabled, plus
VoiceOver, large text, and iPad layout. Expected: native back/dismiss behavior,
accessible action labels, and no clipped controls.

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

Not yet observed, because the simulator build is ad hoc signed and cannot reliably register
the widget's App Entities: any widget placement on the new provider. Pending on a
team-signed device:

1. Upgrade an install that has a configured feed widget. Without opening the app or
   re-adding the widget, it keeps its feed, `/devices/:id/views` shows an event request
   with a legacy feed selection, and it renders with the global appearance.
2. Edit that placement: the editor shows Show plus the retained feed. Choose All my lists,
   then Selected lists; each uses the events route with the new selector and no `feedId`.
   Confirm the conditional editor rows (`parameterSummary`) behave as described above.
3. Add a new placement: it starts on All my lists with no feed picker.
4. Selected with only list A, then leave A in the app: the widget asks for an edit rather
   than showing All; rejoin A and it returns.
5. The Lists picker opens on the first tap, and still opens offline from the last catalog.

Close this status when those five pass. Lock-screen placements, large text, VoiceOver,
multiple widgets, and real-device reminder delivery remain manual acceptance.
