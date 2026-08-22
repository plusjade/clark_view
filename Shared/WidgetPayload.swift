//
//  WidgetPayload.swift
//  Shared
//
//  Created by Jade Dominguez on 8/21/26.
//

import Foundation

/// Decoded shape of the `?format=json` response. This is a *view* contract, not a data
/// contract — the server decides exactly what text to show (matchup names, status word),
/// not raw properties (scores, team ids) for the client to interpret. That keeps the widget a
/// dumb template: any future change to what's displayed ships server-side with no client update.
///
/// `timestamp` is the one deliberate exception to "server owns display text" — it stays raw
/// data so the client can format it for the device's locale/24-hour preference, which the
/// server can't do precisely on the client's behalf.
struct WidgetPayload: Codable {
    let schemaVersion: Int
    /// Small label above the list, e.g. "TODAY" / "TOMORROW" — already formatted for display.
    /// Nil hides it.
    let eyebrow: String?
    let items: [WidgetItem]
}

struct WidgetItem: Codable, Identifiable {
    let id: String
    /// First display line — e.g. the away team's name.
    let mainText: String
    /// Second display line — e.g. the home team's name.
    let subText: String
    /// Pre-formatted status word ("LIVE", "FINAL"). Nil means the game hasn't started —
    /// the client falls back to formatting `timestamp` as a local start time instead.
    let caption: String?
    /// Render `caption` in the attention color (vs. the default dim treatment) — e.g. true
    /// for "LIVE". A view instruction, not a game-status flag: it's read literally, with no
    /// string-matching against `caption`'s wording, so the server owns this decision outright.
    let emphasized: Bool
    /// Unix epoch seconds, UTC.
    let timestamp: Date
}
