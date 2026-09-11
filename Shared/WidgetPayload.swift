//
//  WidgetPayload.swift
//  Shared
//
//  Created by Jade Dominguez on 8/21/26.
//

import Foundation

/// Decoded shape of the `/config/resolve` response. This is a *view* contract, not a data
/// contract — the server decides exactly what text to show (matchup names, status word),
/// not raw properties (scores, team ids) for the client to interpret. That keeps the widget a
/// dumb template: any future change to what's displayed ships server-side with no client update.
///
/// `startsAt` is the one deliberate exception to "server owns display text" — it stays raw
/// data so the client can format it for the device's locale/24-hour preference, which the
/// server can't do precisely on the client's behalf. `expiresAt` is *not* a second exception:
/// it never reaches the screen, and exists only so the widget can schedule its own refresh
/// (see `nextRefreshDate(for:after:)`). Temporal data is used for timing here, never wording.
struct WidgetPayload: Decodable {
    let schemaVersion: Int
    /// Optional server-selected presentation. Older responses omit this field; malformed
    /// presentation data is discarded independently so valid feed items still render.
    let presentation: WidgetPresentationPayload?
    /// Display order — the client renders these in array order with no client-side sort.
    let items: [WidgetItem]

    init(schemaVersion: Int, presentation: WidgetPresentationPayload? = nil, items: [WidgetItem]) {
        self.schemaVersion = schemaVersion
        self.presentation = presentation
        self.items = items
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case presentation
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        presentation = try? container.decode(WidgetPresentationPayload.self, forKey: .presentation)
        items = try container.decode([WidgetItem].self, forKey: .items)
    }
}

struct WidgetItem: Decodable, Identifiable {
    let id: String
    /// The primary title, e.g. a matchup pre-combined by the server as "<team1> @ <team2>" for a
    /// sports source, or a comparable one-line summary from another source. Rendered large/bold
    /// (see `BeaconHeroCard`/`BeaconItemBlockView` in BeaconWidgetTemplate.swift) — can wrap to 2 lines.
    let mainText: String
    /// Secondary detail, e.g. "Channel 7 · local broadcast, not on any streaming app".
    /// Rendered small/dim beneath `mainText`, not at the same weight — can run long, wraps to 2 lines.
    let subText: String
    /// Pre-formatted status word ("LIVE", "END"). Nil means the item hasn't started —
    /// the client falls back to formatting `startsAt` as a local start time instead.
    let caption: String?
    /// Render `caption` in the attention color (vs. the default dim treatment) — e.g. true
    /// for "LIVE". A view instruction, not a status flag derived from the item itself: it's read
    /// literally, with no string-matching against `caption`'s wording, so the server owns this
    /// decision outright.
    let emphasized: Bool
    /// When the event begins. Unix epoch seconds on the wire, UTC. Also drives the per-item
    /// "TODAY"/"TMRW"/"AUG 16" day label (see `dayLabel(for:)` in ClarkViewWidget.swift) —
    /// same locale-formatting rationale as the start-time fallback above.
    let startsAt: Date
    /// When the item stops being current. **An estimate, and never displayed.** The server
    /// publishes a typical duration, not an observed end, so rendering it as a fact ("ends at
    /// 4:15 PM") would state something the system does not know. It is here to bound refresh
    /// scheduling only.
    let expiresAt: Date

    init(
        id: String,
        mainText: String,
        subText: String,
        caption: String?,
        emphasized: Bool,
        startsAt: Date,
        expiresAt: Date
    ) {
        self.id = id
        self.mainText = mainText
        self.subText = subText
        self.caption = caption
        self.emphasized = emphasized
        self.startsAt = startsAt
        self.expiresAt = expiresAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, mainText, subText, caption, emphasized, startsAt, expiresAt
        /// Pre-window field name, still sent alongside `startsAt` during the migration.
        case timestamp
    }

    /// Tolerates the pre-window payload so a build installed before the server's next
    /// deploy — or after a rollback — still renders. An item with no `expiresAt` is treated
    /// as instantaneous rather than given an invented duration: the client has no more idea
    /// than the server how long someone else's event lasts, and an item that is never
    /// "current" simply falls back to the ordinary hourly refresh.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        mainText = try container.decode(String.self, forKey: .mainText)
        subText = try container.decode(String.self, forKey: .subText)
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
        emphasized = try container.decode(Bool.self, forKey: .emphasized)
        startsAt = try container.decodeIfPresent(Date.self, forKey: .startsAt)
            ?? container.decode(Date.self, forKey: .timestamp)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
            ?? startsAt.addingTimeInterval(1)
    }
}

/// When the widget should ask the server again.
///
/// The item window makes this arithmetic rather than guesswork: every start and expiry is a
/// moment the feed's *wording* changes server-side, so the timeline asks for a reload then
/// instead of discovering it up to an hour late. Nothing here reads or renders those bounds
/// as text — the caption still arrives fully formed from the server.
///
/// Bounded on both sides: never sooner than a minute, so a cluster of near-simultaneous
/// events can't burn the refresh budget, and never later than the hourly floor the widget
/// already used.
func nextRefreshDate(for payload: WidgetPayload, after now: Date = .now) -> Date {
    let hourly = now.addingTimeInterval(3600)
    let bounds = payload.items
        .flatMap { [$0.startsAt, $0.expiresAt] }
        .filter { $0 > now }
    guard let next = bounds.min() else { return hourly }
    return min(max(next, now.addingTimeInterval(60)), hourly)
}
