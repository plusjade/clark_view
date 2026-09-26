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
| [ContentView.swift](../clark_view/ContentView.swift), `clark_view/Subscription*.swift`, [FeedPreviewView.swift](../clark_view/FeedPreviewView.swift) | Home: the device's subscriptions index, show (with nested feed preview), new, and edit |
| [WidgetFocusStore.swift](../Shared/WidgetFocusStore.swift), [FocusWidgetItemIntent.swift](../ClarkViewWidget/FocusWidgetItemIntent.swift) | Shared local focus and short interaction-cache window |
| [AppDeepLink.swift](../Shared/AppDeepLink.swift), [DeepLinkRouter.swift](../clark_view/DeepLinkRouter.swift) | `clarkview` subject routes shared by widgets, Live Activities, alert responses, and in-app navigation |
| [DeviceIdentity.swift](../Shared/DeviceIdentity.swift) | Per-install UUID in `group.plusjade.clark-view`; local paired flag is copy-only |
| [PairingClient.swift](../Shared/PairingClient.swift), [DeviceStatusClient.swift](../Shared/DeviceStatusClient.swift) | Self-registration, optional pairing, and diagnostic reads |
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

The app home screen is the device's subscriptions. On first launch the install
creates its own unpaired device row (`POST /devices`), so subscriptions never wait
on pairing; the Pair button stays until the device joins a bunch. The app's feed
preview has no effect on widgets. The one
registered Clark View widget kind is configurable for home and lock screens. Its
native editor has one Feed setting populated from `/feeds`; each widget needs an
explicit choice and retains its opaque feed ID. Old static placements must be
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

Widget inventory is reported from `Provider.timeline` (including unconfigured and
cache-reuse paths), app activation, and successful pairing — never from placeholders,
snapshots, or rendering. It uploads `WidgetCenter.currentConfigurations()` only when the
normalized contents changed, nothing has succeeded, or the last success is 24 hours old;
a failure waits five minutes before the next natural trigger retries (pairing bypasses the
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
on a team-signed device: pair, close the app, add a configured widget, and confirm
`/devices/:id/views` shows it without reopening the app, including whether configurations are readable during the initial
timeline callback. Close this status once that is observed.

The widget extension owns its push entitlement and `.pushHandler`. The containing app
separately requests visible-notification permission, registers an app token, and
uploads it with the last observed alert permission to
`/device/notifications/register`. See [push-notifications.md](push-notifications.md)
for setup, the token/topic contract, and current verification status — don't restate
those facts here.
