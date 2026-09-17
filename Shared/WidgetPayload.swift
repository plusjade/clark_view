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
/// server can't do precisely on the client's behalf. `expiresAt` reaches the screen only
/// through `phase(at:)`, which picks one of the feed's three server-written lifecycle labels;
/// the bound itself is an estimate and is never rendered. It also bounds refresh scheduling
/// (see `nextRefreshDate(for:after:)`).
struct WidgetPayload: Decodable {
    let schemaVersion: Int
    /// Optional server-selected presentation. Older responses omit this field; malformed
    /// presentation data is discarded independently so valid feed items still render.
    let presentation: WidgetPresentationPayload?
    /// One word per lifecycle phase, for every item in the feed. Absent on responses that
    /// predate it, in which case each item's own `caption` is used instead.
    let lifecycle: WidgetLifecycleLabels?
    /// Display order — the client renders these in array order with no client-side sort.
    let items: [WidgetItem]

    init(
        schemaVersion: Int,
        presentation: WidgetPresentationPayload? = nil,
        lifecycle: WidgetLifecycleLabels? = nil,
        items: [WidgetItem]
    ) {
        self.schemaVersion = schemaVersion
        self.presentation = presentation
        self.lifecycle = lifecycle
        self.items = items
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case presentation
        case lifecycle
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        presentation = try? container.decode(WidgetPresentationPayload.self, forKey: .presentation)
        lifecycle = try? container.decode(WidgetLifecycleLabels.self, forKey: .lifecycle)
        items = try container.decode([WidgetItem].self, forKey: .items)
    }
}

/// Where an item sits relative to its own window. State, never display text.
enum WidgetPhase {
    case upcoming
    case current
    case expired
}

/// The server's word for each lifecycle phase, sent once for the whole feed.
///
/// `nil` for a phase means *no word*, and the client formats `startsAt` as a local clock
/// time instead — the one display decision the server can't make, since it doesn't know the
/// device's locale or 24-hour preference.
///
/// This is deliberately not per item: lifecycle wording is one vocabulary for the product,
/// not a property of any source's data. The client resolves the phase against its own clock
/// on every render, so the word stays right between refreshes.
struct WidgetLifecycleLabels: Decodable, Equatable {
    let upcoming: String?
    let current: String?
    let expired: String?

    init(upcoming: String? = nil, current: String? = nil, expired: String? = nil) {
        self.upcoming = upcoming
        self.current = current
        self.expired = expired
    }

    func label(for phase: WidgetPhase) -> String? {
        switch phase {
        case .upcoming: return upcoming
        case .current: return current
        case .expired: return expired
        }
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
    /// Retired, and read only when the payload has no `lifecycle` labels — the server
    /// resolved this against its own clock at compose time, so it can be an hour stale.
    /// Drop it once no server sends it.
    let caption: String?
    /// Retired and never rendered. It shipped as a "draw the caption in the attention color"
    /// instruction that no template ever implemented. Decoded leniently so removing it
    /// server-side can't break a feed. Drop it with `caption`.
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
        caption: String? = nil,
        emphasized: Bool = false,
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
        emphasized = try container.decodeIfPresent(Bool.self, forKey: .emphasized) ?? false
        startsAt = try container.decodeIfPresent(Date.self, forKey: .startsAt)
            ?? container.decode(Date.self, forKey: .timestamp)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
            ?? startsAt.addingTimeInterval(1)
    }
}

extension WidgetItem {
    /// The item's lifecycle state at `now`, from its own window. Half-open: an item is
    /// `current` from its start up to but not including its expiry, which is what makes a
    /// one-second window current for exactly one second.
    func phase(at now: Date) -> WidgetPhase {
        if now < startsAt { return .upcoming }
        return now < expiresAt ? .current : .expired
    }

    /// The word to show for this item, or nil to format `startsAt` as a local time.
    ///
    /// Resolving here rather than reading a server-resolved string is the point of the
    /// labels: WidgetKit may render an entry well after it was fetched, and a word chosen
    /// at compose time would still say "LIVE" for an event that has since ended.
    func lifecycleLabel(_ labels: WidgetLifecycleLabels?, at now: Date) -> String? {
        guard let labels else { return caption }
        return labels.label(for: phase(at: now))
    }
}

/// Every moment the feed's wording changes, still ahead of `now`.
///
/// One timeline entry per bound is what makes the lifecycle a state machine *on the device*:
/// the same payload rendered at each bound resolves to the next label with no fetch. The
/// reload in `nextRefreshDate(for:after:)` lands on the first of these, so in the ordinary
/// case these entries are belt-and-braces — WidgetKit treats a refresh policy as a request,
/// not a promise, and a late reload would otherwise leave "LIVE" on an ended event.
///
/// Capped because a feed of many items would otherwise build a timeline the system trims
/// arbitrarily; the earliest bounds are the ones that matter.
func lifecycleEntryDates(for payload: WidgetPayload, after now: Date = .now, limit: Int = 24) -> [Date] {
    let bounds = payload.items.flatMap { [$0.startsAt, $0.expiresAt] }.filter { $0 > now }
    return Array(Set(bounds).sorted().prefix(limit))
}

/// When the widget should ask the server again.
///
/// The item window makes this arithmetic rather than guesswork: every start and expiry is a
/// moment the feed's *wording* changes, so the timeline asks for a reload then instead of
/// discovering it up to an hour late. The wording itself needs no reload — the entries from
/// `lifecycleEntryDates(for:after:limit:)` already cover it; this keeps the *content* fresh.
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
