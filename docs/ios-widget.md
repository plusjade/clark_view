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
| [ServerURL.swift](../Shared/ServerURL.swift), [Feed.swift](../Shared/Feed.swift) | Base URL and public feed client |
| [WidgetPayload.swift](../Shared/WidgetPayload.swift), [WidgetPresentation.swift](../Shared/WidgetPresentation.swift) | Wire decoding and presentation fallback |
| [BeaconDateTimeView.swift](../Shared/BeaconDateTimeView.swift) | Shared widget/app lifecycle date line and local day label |
| [ClarkViewWidget.swift](../ClarkViewWidget/ClarkViewWidget.swift), [WidgetFeedIntent.swift](../Shared/WidgetFeedIntent.swift) | Configurable feed choice, fetch, preview fixtures, timeline, entry view |
| [BeaconWidgetTemplate.swift](../ClarkViewWidget/BeaconWidgetTemplate.swift) | Default widget layout and event deep links |
| [ContentView.swift](../clark_view/ContentView.swift), `clark_view/Subscription*.swift`, [FeedPreviewView.swift](../clark_view/FeedPreviewView.swift) | Your feeds, public browse and pre-join preview, reminder switch, and leave |
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

The app home screen is Your feeds. On first launch the install creates its own
device row (`POST /devices`). Public feeds can be browsed and previewed before
joining. A join starts with Reminders off; the switch can be changed later, and
Leave feed removes this device's join. The feed owns one shared reminder timing,
shown in the preview, and browser configuration can change it. The app's feed
preview has no effect on widgets. The one
registered Clark View widget kind is configurable for home and lock screens. Its
native editor has one Feed setting populated from the App Group catalog in
`Shared/WidgetFeedCatalog.swift`. Configuration queries perform no network requests
and offer no automatic default; users explicitly choose a feed. The app replaces
picker choices after each successful subscription load and updates them immediately
after successful joins/leaves. Failed loads preserve the last successful snapshot.
Open or refresh the app after browser-side membership changes or renames; the picker
reflects the last locally observed state, not live server membership. After upgrading,
open the app online once to populate choices. An empty catalog offers no choices.
The public `/feeds` directory remains exclusive to the app's Join Feed flow.

Each widget retains its own opaque feed ID. Remembered names survive leaving a feed,
so existing selections resolve independently of the current choices, including offline.
Older selections absent from the catalog resolve as `Feed <ID>` until their name is
learned through an app subscription load. Feed existence is checked by the normal
timeline fetch; a deleted feed still produces the unavailable state. The retired
`lastJoinedWidgetFeed` preference is ignored. Old static placements must be replaced,
and old Follow app configurations must be edited to choose a feed.
Widget choice creates no notification subscription. A missing feed asks the user
to Edit Widget; an unconfigured widget asks for a feed. Temporary network failure
does not replace a configured ID. The app's manual widget refresh control still
requests a timeline reload;
WidgetKit controls when it runs. The app reuses the widget's date line, refreshes
when opened or foregrounded, and supports pull to refresh. Notification setup and its
diagnostics live under the toolbar menu's Notifications entry.
Ordinary public feed URLs retain their existing browser behavior. The app does
not intercept them as a Join feed deep link; a receiver browses the in-app
directory to join by name. Recheck this gap only if link-driven joining becomes
a product requirement.

Widget inventory is reported from `Provider.timeline` (including unconfigured paths),
app activation, and successful registration — never from placeholders,
snapshots, or rendering. It uploads `WidgetCenter.currentConfigurations()` only when the
normalized contents changed, nothing has succeeded, or the last success is 24 hours old;
a failure waits five minutes before the next natural trigger retries (registration bypasses the
wait). The timeline awaits the reporter alongside the feed fetch; the reporter bounds
itself to three seconds and never fails the timeline. A failed configuration query is not
uploaded as an empty inventory. Feed reads send installation, caller, family, and purpose
headers for server receipts. Reports can lag: removing the last widget runs no timeline,
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

Pending on a team-signed device: open the app online to populate joins, add one
widget, open Feed once, select a feed, and confirm the widget renders it. Repeat
opening the picker offline (choices should remain available; content loading still
requires the network). Leave the selected feed in the app: it should disappear from
new choices while the placed widget retains its selection. Verify an upgraded
placement before/after the first app refresh, an empty membership list, and a browser
rename/membership change followed by app refresh. Close after first-tap presentation
and retained selections pass; multiple-widget and lock-screen combinations remain
manual acceptance.
