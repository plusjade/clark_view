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
| [ServerURL.swift](../Shared/ServerURL.swift) | Base URL and resolver query |
| [WidgetPayload.swift](../Shared/WidgetPayload.swift), [WidgetPresentation.swift](../Shared/WidgetPresentation.swift) | Wire decoding and presentation fallback |
| [BeaconDateTimeView.swift](../Shared/BeaconDateTimeView.swift) | Shared widget/app lifecycle date line and local day label |
| [ClarkViewWidget.swift](../ClarkViewWidget/ClarkViewWidget.swift) | Fetch/cache, preview fixtures, hourly timeline, entry view |
| [BeaconWidgetTemplate.swift](../ClarkViewWidget/BeaconWidgetTemplate.swift), [BeaconWidgetFocusLayouts.swift](../ClarkViewWidget/BeaconWidgetFocusLayouts.swift) | Default layout and focus transition |
| [ContentView.swift](../clark_view/ContentView.swift), [FeedHomeView.swift](../clark_view/FeedHomeView.swift) | Paired/unpaired entry and the app's full feed list |
| [WidgetFocusStore.swift](../Shared/WidgetFocusStore.swift), [FocusWidgetItemIntent.swift](../ClarkViewWidget/FocusWidgetItemIntent.swift) | Shared local focus and short interaction-cache window |
| [AppDeepLink.swift](../Shared/AppDeepLink.swift), [DeepLinkRouter.swift](../clark_view/DeepLinkRouter.swift) | `clarkview` subject routes shared by widgets, Live Activities, alert responses, and in-app navigation |
| [DeviceIdentity.swift](../Shared/DeviceIdentity.swift) | Per-install UUID in `group.plusjade.clark-view`; local paired flag is copy-only |
| [PairingClient.swift](../Shared/PairingClient.swift), [DeviceStatusClient.swift](../Shared/DeviceStatusClient.swift) | Enrollment and diagnostic reads |
| [PushTokenClient.swift](../Shared/PushTokenClient.swift), [ClarkViewWidgetPushHandler.swift](../ClarkViewWidget/ClarkViewWidgetPushHandler.swift) | Native widget token upload/removal |
| [WidgetRefreshDiagnostics.swift](../Shared/WidgetRefreshDiagnostics.swift), [WidgetDiagnosticsView.swift](../clark_view/WidgetDiagnosticsView.swift) | Last manual request, network attempt, success/failure and app reload controls |

Beacon small/medium show the first item; large shows the first two. Local focus
expands either item in place without reordering server items (`StaticConfiguration`
means focus is shared across instances) and uses a 15-second cache-reuse window on the
last decoded App Group payload; explicit refresh clears that window. Ordinary
network/decoding failure currently returns an empty payload, not stale cached content
— distinguish failed fetches from successful empty feeds in diagnostics. Beacon has no
refresh button; manual refresh lives in the app only. Reload requests ask WidgetKit
for a timeline and do not guarantee immediate execution; the normal timeline requests
an hourly refresh. Native accented/vibrant appearances remain system-owned; Beacon respects
Reduce Motion and Reduce Transparency. Consult Swift for geometry, not this file.

The app opens pairing until the install is paired, then reads `/config/resolve` for
its full feed. Its first item follows the large widget's focused card hierarchy;
the remaining items use compact cards. The app reuses the widget's date line, refreshes
when opened or foregrounded, and supports pull to refresh. Notification setup and its
diagnostics live under the toolbar menu's Notifications entry.

Widget and Live Activity taps carry their displayed snapshot through the app-owned
`clarkview` URL scheme and push a native detail destination. In the large widget, a
compact item still expands in place first; tapping the focused item opens its detail.
The route is presentation-only and performs no mutation or server lookup.

The widget extension owns its push entitlement and `.pushHandler`. The containing app
separately requests visible-notification permission, registers an app token, and
uploads it with the last observed alert permission to
`/device/notifications/register`. See [push-notifications.md](push-notifications.md)
for setup, the token/topic contract, and current verification status — don't restate
those facts here.
