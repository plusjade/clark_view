//
//  ClarkViewWidget.swift
//  ClarkViewWidget
//
//  Created by Jade Dominguez on 8/18/26.
//

import WidgetKit
import SwiftUI

private enum GameDataService {
    static func fetchPayload(day: GameDay, teams: [FavoriteTeam]) async -> WidgetPayload {
        let request = URLRequest(
            url: GameImageURL.jsonURL(
                day: day.rawValue,
                tzSecondsFromGMT: TimeZone.current.secondsFromGMT(),
                teamIDs: teams.map(\.id)
            ),
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return .empty
            }
            return try JSONDecoder.widgetPayload.decode(WidgetPayload.self, from: data)
        } catch {
            return .empty
        }
    }

    /// Drives both the live provider and #Preview until the server mirrors the v2
    /// (schemaVersion 2, item-list) contract — the live endpoint still returns v1 as of this
    /// writing. Swap `fetchPayload`'s call site back to the network fetch below once it does;
    /// `fetchPayload` itself is left wired up and unchanged so that's a one-line flip.
    static var mockPayload: WidgetPayload {
        (try? JSONDecoder.widgetPayload.decode(WidgetPayload.self, from: mockJSON)) ?? .empty
    }

    private static let mockJSON = Data("""
    {
      "schemaVersion": 2,
      "eyebrow": "TODAY",
      "items": [
        {
          "id": "1", "mainText": "Fever @ Wings",
          "subText": "Channel 7 · local broadcast, not on any streaming app",
          "caption": null, "emphasized": false, "timestamp": 1787443200
        },
        {
          "id": "2", "mainText": "Valkyries @ Sparks",
          "subText": "AMZN · Prime Video, subscription required",
          "caption": null, "emphasized": false, "timestamp": 1787450400
        }
      ]
    }
    """.utf8)
}

private extension WidgetPayload {
    static let empty = WidgetPayload(schemaVersion: 2, eyebrow: nil, items: [])
}

private extension JSONDecoder {
    static let widgetPayload: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()
}

struct GamesEntry: TimelineEntry {
    let date: Date
    let payload: WidgetPayload
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> GamesEntry {
        GamesEntry(date: .now, payload: .empty)
    }

    typealias Intent = ClarkViewWidgetConfigurationIntent

    func snapshot(for configuration: Intent, in context: Context) async -> GamesEntry {
        // Swap for GameDataService.fetchPayload(day:teams:) once the server mirrors the v2
        // (schemaVersion 2, item-list) contract — it still returns v1 as of this writing.
        GamesEntry(date: .now, payload: GameDataService.mockPayload)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<GamesEntry> {
        let entry = GamesEntry(date: .now, payload: GameDataService.mockPayload)
        // Data doesn't change fast enough to justify burning the refresh budget more often
        // than this; retune if games start/finish mid-refresh-window.
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 60, to: .now)
        return Timeline(entries: [entry], policy: .after(nextRefresh ?? .now.addingTimeInterval(3600)))
    }
}

/// An item's matchup title ("<team1> @ <team2>") — no score, no live clock. `lineLimit` defaults
/// to a single line; the list row raises it so long matchups wrap instead of hitting the rail.
private struct ItemLineView: View {
    let text: String
    let font: Font
    var lineLimit: Int = 1

    var body: some View {
        Text(text)
            .font(font)
            .lineLimit(lineLimit)
    }
}

/// Status stays a single word or a bare time — never the live-game clock/quarter, and never
/// a score. The server pre-formats `caption` ("LIVE"/"FINAL") and decides `emphasized` for
/// the view-based contract; the one exception is the not-yet-started case, where the client
/// formats the raw `timestamp` itself so it respects the device's locale/24-hour setting.
private func displayCaption(for item: WidgetItem) -> (text: String, color: Color) {
    guard let caption = item.caption else {
        return (item.timestamp.formatted(date: .omitted, time: .shortened), .white.opacity(0.6))
    }
    return (caption, item.emphasized ? .red : .white.opacity(0.55))
}

/// "TODAY" gets a rich yellow + heavy weight to draw the eye; every other eyebrow value (e.g.
/// "TOMORROW") stays the existing dim, lighter-weight treatment.
private func eyebrowStyle(for eyebrow: String) -> (color: Color, weight: Font.Weight) {
    eyebrow == "TODAY" ? (Color(red: 1.0, green: 0.78, blue: 0.0), .heavy) : (.white.opacity(0.5), .semibold)
}

/// Hour/minute/period split for TimeBlockView's stacked layout. `period` is nil on 24-hour
/// locales, where there's no AM/PM to stack — the view falls back to a plain "HH:MM" line.
private struct TimeParts {
    let hour: String
    let minute: String
    let period: String?
}

private func timeParts(for date: Date) -> TimeParts {
    let locale = Locale.autoupdatingCurrent
    let calendar = Calendar.autoupdatingCurrent
    let components = calendar.dateComponents([.hour, .minute], from: date)
    let minute = String(format: "%02d", components.minute ?? 0)

    let usesTwelveHour = (DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? "").contains("a")
    guard usesTwelveHour else {
        return TimeParts(hour: String(format: "%02d", components.hour ?? 0), minute: minute, period: nil)
    }

    var hour = (components.hour ?? 0) % 12
    if hour == 0 { hour = 12 }
    let periodFormatter = DateFormatter()
    periodFormatter.locale = locale
    periodFormatter.dateFormat = "a"
    return TimeParts(hour: String(hour), minute: minute, period: periodFormatter.string(from: date))
}

/// Trailing time display for the list layout: a large hour digit with minute/period stacked
/// beside it, mirroring a scoreboard clock. Falls back to `caption` (e.g. "LIVE"/"FINAL") when
/// the game isn't in the not-yet-started state, same as displayCaption but laid out for a rail.
private struct TimeBlockView: View {
    let item: WidgetItem

    var body: some View {
        if let caption = item.caption {
            Text(caption)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(item.emphasized ? .red : .white.opacity(0.55))
        } else {
            let parts = timeParts(for: item.timestamp)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(parts.hour)
                    .font(.system(.largeTitle, design: .monospaced, weight: .black))
                if let period = parts.period {
                    VStack(alignment: .leading, spacing: -2) {
                        Text(parts.minute)
                        Text(period)
                    }
                    .font(.system(.caption, design: .monospaced, weight: .black))
                } else {
                    Text(":\(parts.minute)")
                        .font(.system(.largeTitle, design: .monospaced, weight: .black))
                }
            }
            .foregroundStyle(.white)
        }
    }
}

private struct StackSizeKey: PreferenceKey {
    static var defaultValue = CGSize(width: 260, height: 200)
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

/// Measures `content`'s natural (unscaled) size via a hidden clone, then applies one shared
/// `scaleEffect` so it fills as much of the available frame as the tighter of width/height
/// allows. Base fonts still come from a TextStyle, so the accessibility scaling curve is
/// preserved: bump system text size and the natural measurement grows too, shrinking the
/// computed multiplier to compensate rather than overflowing.
///
/// Caveat: this is a two-pass measure-then-render technique, and WidgetKit snapshots the view
/// rather than live-rendering it — `StackSizeKey`'s default is seeded close to a real
/// measurement so an early snapshot isn't wildly wrong, but a flash of oddly-scaled text on
/// first placement is this mechanism to revisit.
private struct AutoFitStack<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    @State private var naturalSize = StackSizeKey.defaultValue

    var body: some View {
        GeometryReader { proxy in
            let widthScale = proxy.size.width / max(naturalSize.width, 1)
            let heightScale = proxy.size.height / max(naturalSize.height, 1)
            let scale = min(widthScale, heightScale)

            VStack(alignment: .leading, spacing: spacing) { content() }
                .fixedSize()
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .background(
                    VStack(alignment: .leading, spacing: spacing) { content() }
                        .fixedSize()
                        .opacity(0)
                        .background(GeometryReader { measured in
                            Color.clear.preference(key: StackSizeKey.self, value: measured.size)
                        })
                )
        }
        .onPreferenceChange(StackSizeKey.self) { naturalSize = $0 }
    }
}

/// Small widget: one item, maximized. This is deliberately not a scaled-down version of the
/// multi-item layout below — small is a single-glance case, so it gets its own full-bleed
/// template instead of being squeezed into the block layout medium/large share.
private struct ItemHeroCard: View {
    let item: WidgetItem
    let eyebrow: String?

    private var heroFont: Font {
        .system(.largeTitle, design: .default, weight: .black)
    }

    var body: some View {
        let caption = displayCaption(for: item)
        VStack(alignment: .leading, spacing: 8) {
            if let eyebrow {
                let style = eyebrowStyle(for: eyebrow)
                Text(eyebrow)
                    .font(.system(.caption2, design: .rounded, weight: style.weight))
                    .tracking(1.5)
                    .foregroundStyle(style.color)
            }

            AutoFitStack(spacing: 4) {
                ItemLineView(text: item.mainText, font: heroFont)
            }

            Text(item.subText)
                .font(.system(.subheadline, design: .default, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(2)

            Text(caption.text)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(caption.color)
        }
        .foregroundStyle(.white)
    }
}

/// One item's block within the medium/large list: a header row (matchup title top-aligned
/// against the time rail, so a wrapped second line grows downward instead of pulling the row
/// up) plus a broadcast line beneath spanning the full width, scaled together by AutoFitStack.
///
/// Title and time rail each get a dedicated fixed width instead of negotiating for space, so
/// the rail stays fully visible and a long title wraps in its own column rather than shoving
/// it out of view — also what makes wrapping resolvable at all inside AutoFitStack's
/// `.fixedSize()` pass, which proposes nil width here.
private struct ItemBlockView: View {
    let item: WidgetItem

    // Confirmed (2026-08-20): Font.system(size:...) silently drops `design` here; only the
    // TextStyle-relative initializer threads it correctly. Default (sans), not monospaced —
    // that rationale is for the time rail's digits only.
    private var titleFont: Font {
        .system(.title2, design: .default, weight: .black)
    }

    private static let rowWidth: CGFloat = 254
    private static let timeBlockWidth: CGFloat = 56
    private static let headerSpacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: Self.headerSpacing) {
                ItemLineView(text: item.mainText, font: titleFont, lineLimit: 2)
                    .frame(
                        width: Self.rowWidth - Self.timeBlockWidth - Self.headerSpacing,
                        alignment: .leading
                    )
                    .fixedSize(horizontal: false, vertical: true)

                TimeBlockView(item: item)
                    .frame(width: Self.timeBlockWidth, alignment: .trailing)
            }
            .frame(width: Self.rowWidth, alignment: .leading)

            Text(item.subText)
                .font(.system(.footnote, design: .default, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(2)
                .frame(width: Self.rowWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ClarkViewWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    private var visibleItems: [WidgetItem] {
        family == .systemMedium ? Array(entry.payload.items.prefix(1)) : Array(entry.payload.items.prefix(3))
    }

    var body: some View {
        Group {
            if entry.payload.items.isEmpty {
                Image(systemName: "sportscourt")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            } else if family == .systemSmall, let item = entry.payload.items.first {
                ItemHeroCard(item: item, eyebrow: entry.payload.eyebrow)
                    .padding(14)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if let eyebrow = entry.payload.eyebrow {
                        let style = eyebrowStyle(for: eyebrow)
                        Text(eyebrow)
                            .font(.system(.caption, design: .rounded, weight: style.weight))
                            .tracking(1.5)
                            .foregroundStyle(style.color)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    AutoFitStack(spacing: family == .systemMedium ? 10 : 14) {
                        ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                            if index > 0 {
                                // A system Divider() renders unpredictably under AutoFitStack's
                                // scaleEffect; a plain rectangle scales reliably with everything else.
                                Rectangle()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 1)
                            }
                            ItemBlockView(item: item)
                        }
                    }
                    .foregroundStyle(.white)
                }
                .padding(18)
            }
        }
        .containerBackground(.black, for: .widget)
    }
}

struct ClarkViewWidget: Widget {
    let kind: String = "ClarkViewWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind, intent: ClarkViewWidgetConfigurationIntent.self, provider: Provider()
        ) { entry in
            ClarkViewWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Games")
        .description("Shows a day's games.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    ClarkViewWidget()
} timeline: {
    GamesEntry(date: .now, payload: GameDataService.mockPayload)
    GamesEntry(date: .now, payload: .empty)
}

#Preview(as: .systemMedium) {
    ClarkViewWidget()
} timeline: {
    GamesEntry(date: .now, payload: GameDataService.mockPayload)
}

#Preview(as: .systemLarge) {
    ClarkViewWidget()
} timeline: {
    GamesEntry(date: .now, payload: GameDataService.mockPayload)
}
