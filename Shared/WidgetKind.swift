//
//  WidgetKind.swift
//  Shared
//
//  Created by Jade Dominguez on 8/28/26.
//

import Foundation

/// The one widget kind this app ships, shared between the app (which calls
/// `WidgetCenter.shared.reloadTimelines(ofKind:)`) and the extension (whose
/// `Widget.kind` this must match exactly).
enum WidgetKind {
    static let main = "ClarkViewWidget"
}
