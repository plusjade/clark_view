# Clark View iOS widget implementation

The widget and app side of Clark View: file roles, Beacon behavior, refresh and
focus semantics, deep links, and push entitlement. The server contracts these
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
| [ClarkViewWidget.swift](../ClarkViewWidget/ClarkViewWidget.swift), [WidgetFeedIntent.swift](../Shared/WidgetFeedIntent.swift) | Configurable feed choice, fetch/cache, preview fixtures, timeline, entry view |
| [BeaconWidgetTemplate.swift](../ClarkViewWidget/BeaconWidgetTemplate.swift), [BeaconWidgetFocusLayouts.swift](../ClarkViewWidget/BeaconWidgetFocusLayouts.swift) | Default layout and focus transition |
| [ContentView.swift](../clark_view/ContentView.swift), `clark_view/Subscription*.swift`, [FeedPreviewView.swift](../clark_view/FeedPreviewView.swift) | Your feeds, public browse and pre-join preview, reminder switch, and leave |
| [WidgetFocusStore.swift](../Shared/WidgetFocusStore.swift), [FocusWidgetItemIntent.swift](../ClarkViewWidget/FocusWidgetItemIntent.swift) | Shared local focus and short interaction-cache window |
| [AppDeepLink.swift](../Shared/AppDeepLink.swift), [DeepLinkRouter.swift](../clark_view/DeepLinkRouter.swift) | `clarkview` subject routes shared by widgets, Live Activities, alert responses, and in-app navigation |
| [DeviceIdentity.swift](../Shared/DeviceIdentity.swift), [DeviceStatusClient.swift](../Shared/DeviceStatusClient.swift) | Per-install UUID in `group.plusjade.clark-view`, self-registration, and diagnostic reads |
| [PushTokenClient.swift](../Shared/PushTokenClient.swift), [ClarkViewWidgetPushHandler.swift](../ClarkViewWidget/ClarkViewWidgetPushHandler.swift) | Native widget token upload/removal |
| [WidgetInventory.swift](../Shared/WidgetInventory.swift), [WidgetInventoryReporter.swift](../Shared/WidgetInventoryReporter.swift) | Widget inventory snapshot, upload policy, and coalesced reporter |
| [WidgetRefreshDiagnostics.swift](../Shared/WidgetRefreshDiagnostics.swift), [WidgetDiagnosticsView.swift](../clark_view/WidgetDiagnosticsView.swift) | Last manual request, network attempt, success/failure and app reload controls |

Beacon small/medium show the first item; large shows the first two. Local focus
expands either item in place without reordering server items. Widgets showing the
same feed share focus; each feed has its own focus and a 15-second cache-reuse window.
Explicit refresh bypasses that window. Ordinary
network/decoding failure currently returns an empty payload, not stale cached content
— distinguish failed fetches from successful empty feeds in diagnostics. Beacon has no
refresh button; manual refresh lives in the app only. Reload requests ask WidgetKit
for a timeline and do not guarantee immediate execution; the normal timeline requests
an hourly refresh. Native accented/vibrant appearances remain system-owned; Beacon respects
Reduce Motion and Reduce Transparency. Consult Swift for geometry, not this file.

The app home screen is Your feeds. On first launch the install creates its own
device row (`POST /devices`). Public feeds can be browsed and previewed before
joining. A join starts with Reminders off; the switch can be changed later, and
Leave feed removes this device's join. The feed owns one shared reminder timing,
shown in the preview, and browser configuration can change it. The app's feed
preview has no effect on widgets. The one
registered Clark View widget kind is configurable for home and lock screens. Its
native editor has one Feed setting populated from `/feeds`. A successful in-app
join saves its feed ID and name in the App Group; `WidgetFeedQuery.defaultResult()`
offers that local value as the configuration default, even offline. iOS controls
when it queries this default; a new placement is not guaranteed to query again
(see the dated acceptance status below). Each widget retains
its own opaque feed ID and can override the default in Edit Widget. Existing
placements never follow later joins. With no saved join, selection remains empty.
The saved default tracks successful joins on this installation from this version
onward, not browsing, reminder changes, browser joins, or historical joins. Leaving
a feed does not erase this last-joined preference; public widget selection remains
independent of subscriptions. Old static placements must be
replaced, and old Follow app configurations must be edited to choose a feed.
The intent query resolves names from `/feeds`, so a server rename appears when
the editor next resolves the stored ID.
Widget choice creates no notification subscription. A missing feed asks the user
to Edit Widget; an unconfigured widget asks for a feed. Temporary network failure
does not replace a configured ID. Widgets showing the same feed share focus and
cache. The app's manual widget refresh control still requests a timeline reload;
WidgetKit controls when it runs. The first item follows the large widget's focused card hierarchy;
the remaining items use compact cards. The app reuses the widget's date line, refreshes
when opened or foregrounded, and supports pull to refresh. Notification setup and its
diagnostics live under the toolbar menu's Notifications entry.
Ordinary public feed URLs retain their existing browser behavior. The app does
not intercept them as a Join feed deep link; a receiver browses the in-app
directory to join by name. Recheck this gap only if link-driven joining becomes
a product requirement.

Widget inventory is reported from `Provider.timeline` (including unconfigured and
cache-reuse paths), app activation, and successful registration — never from placeholders,
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
`clarkview` URL scheme and push a native detail destination. In the large widget, a
compact item still expands in place first; tapping the focused item opens its detail.
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

### Last-joined widget default acceptance (2026-09-27)

User device verification passed for a fresh install: joining A then adding the
first widget selected A. It failed for subsequent placement: after joining B,
the second widget still selected A. Exact OS version and query invocations were
not captured. The intended behavior remains B for the second widget and A for
the existing widget; currently the native default is best effort.

Review confirmed `SubscriptionStore.create` records every successful join, and
an isolated execution of `WidgetFeedDefault` confirmed writes advance A to B.
That verifies local preference replacement, not cross-process visibility or
WidgetKit query timing on the affected device. Suspected cause: WidgetKit reuses
its initial default configuration, matching this
[developer report](https://developer.apple.com/forums/thread/766959).
Apple documents that
[`invalidateConfigurationRecommendations()`](https://developer.apple.com/documentation/widgetkit/widgetcenter/invalidateconfigurationrecommendations())
is inactive on iOS; timeline reload APIs do not promise to invalidate defaults.
No speculative reload or replacement of existing widget selections was added.

For further diagnosis on a team-signed device, inspect the App Group
`lastJoinedWidgetFeed` value after joining B and trace whether
`WidgetFeedQuery.defaultResult()` is called when adding the second widget.
If called, inspect the value it reads; if not, investigate system configuration
reuse. Close when the A-then-B placement flow reliably selects B for the new
widget without changing A on the existing widget. Until then, use Edit Widget
on the new placement to choose B. Manual overrides, offline placement, and the
no-join state remain unverified.
