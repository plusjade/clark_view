//
//  RefreshWidgetIntent.swift
//  ClarkViewWidget
//
//  Created by Jade Dominguez on 8/29/26.
//

import AppIntents
import WidgetKit

/// Backs the on-widget refresh button (see `ClarkViewWidgetEntryView`).
/// Runs entirely in this extension's process — no `openAppWhenRun`, so
/// tapping it never launches the app — and just forces WidgetKit past its
/// own hourly timeline policy, same as `PairingView` already does after a
/// successful pair.
struct RefreshWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh"

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.main)
        return .result()
    }
}
