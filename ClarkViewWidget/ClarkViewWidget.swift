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
          "id": "1", "mainText": "Sparks", "subText": "Fever",
          "caption": "LIVE", "emphasized": true, "timestamp": 1787345100
        },
        {
          "id": "2", "mainText": "Dodgers", "subText": "Giants",
          "caption": null, "emphasized": false, "timestamp": 1787357400
        },
        {
          "id": "3", "mainText": "Warriors", "subText": "Lakers",
          "caption": "FINAL", "emphasized": false, "timestamp": 1787335200
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

/// One line of an item's main/sub text — no score, no live clock. The widget's whole value
/// proposition is showing just "which of my teams, and when," not duplicating what every
/// other sports app already shows; see displayCaption below for the same principle applied
/// to status.
private struct ItemLineView: View {
    let text: String
    let font: Font

    var body: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
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

private struct StackSizeKey: PreferenceKey {
    static var defaultValue = CGSize(width: 260, height: 200)
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

/// Measures `content`'s natural (unscaled) size via a hidden clone, then applies one shared
/// `scaleEffect` so it fills as much of the available frame as the tighter of width/height
/// allows — near full-bleed, capped by whichever axis runs out first. Because the base fonts
/// inside `content` still come from a TextStyle (see nameFont's comment on why that matters),
/// the accessibility scaling curve is preserved: bump the system text size and the natural
/// (pre-scale) measurement grows too, so the computed multiplier shrinks to compensate rather
/// than overflowing the frame. Generic over one item's two lines (small) or several items'
/// worth of blocks stacked together (medium/large) — same mechanism either way.
///
/// Caveat worth verifying on-device: this is a two-pass measure-then-render technique, and
/// WidgetKit snapshots the view for the Home Screen rather than live-rendering it — the
/// `StackSizeKey` default is seeded close to a real measurement so a snapshot taken before the
/// preference propagates isn't wildly wrong, but if you see a flash of oddly-scaled text on
/// first placement, that's the mechanism to revisit.
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
        .system(.largeTitle, design: .monospaced, weight: .black)
    }

    var body: some View {
        let caption = displayCaption(for: item)
        VStack(alignment: .leading, spacing: 8) {
            if let eyebrow {
                Text(eyebrow)
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.5))
            }

            AutoFitStack(spacing: 4) {
                ItemLineView(text: item.mainText, font: heroFont)
                ItemLineView(text: item.subText, font: heroFont)
            }

            Text(caption.text)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(caption.color)
        }
        .foregroundStyle(.white)
    }
}

/// One item's block within the medium/large stack: two text lines + a status caption, all
/// measured and scaled together by the enclosing AutoFitStack so caption-to-text proportions
/// stay consistent as the shared scale grows or shrinks.
private struct ItemBlockView: View {
    let item: WidgetItem

    // Confirmed (2026-08-20): any Font.system(size:...) construction silently drops `design`
    // in this widget's rendering pipeline, regardless of how weight is attached. Only the
    // TextStyle-relative initializer (.system(_:design:weight:)) threads `design` correctly
    // here — the reference tier only sets the *relative* size vs. the caption below; the
    // enclosing AutoFitStack rescales the whole block to fit anyway.
    private var textFont: Font {
        .system(.title2, design: .monospaced, weight: .black)
    }

    var body: some View {
        let caption = displayCaption(for: item)
        VStack(alignment: .leading, spacing: 2) {
            ItemLineView(text: item.mainText, font: textFont)
            ItemLineView(text: item.subText, font: textFont)
            Text(caption.text)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(caption.color)
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
                        Text(eyebrow)
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    AutoFitStack(spacing: family == .systemMedium ? 10 : 14) {
                        ForEach(visibleItems) { item in
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
