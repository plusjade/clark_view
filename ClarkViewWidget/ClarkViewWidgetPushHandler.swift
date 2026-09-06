//
//  ClarkViewWidgetPushHandler.swift
//  ClarkViewWidget
//

import WidgetKit

/// Registers WidgetKit's own APNs token, allowing server changes to refresh the widget
/// without waking or launching the containing app.
struct ClarkViewWidgetPushHandler: WidgetPushHandler {
    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo]) {
        let isActive = widgets.contains { $0.kind == WidgetKind.main }
        Task {
            await PushTokenClient.updateWidgetToken(
                device: DeviceIdentity.deviceID,
                token: pushInfo.token,
                active: isActive
            )
        }
    }
}
