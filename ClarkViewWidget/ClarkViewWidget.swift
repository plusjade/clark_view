//
//  ClarkViewWidget.swift
//  ClarkViewWidget
//
//  Created by Jade Dominguez on 8/18/26.
//

import AppIntents
import WidgetKit
import SwiftUI
import UIKit

private enum GameDataService {
    static func fetchPayload(context: Provider.Context) async -> WidgetPayload {
        let scale = UITraitCollection.current.displayScale
        let pixelWidth = Int((context.displaySize.width * scale).rounded())
        let pixelHeight = Int((context.displaySize.height * scale).rounded())
        let request = URLRequest(
            url: GameDataURL.resolveURL(
                device: DeviceIdentity.deviceID,
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight,
                tzSecondsFromGMT: TimeZone.current.secondsFromGMT()
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

    /// #Preview-only fixture now that the live provider calls `fetchPayload` directly — keeps
    /// Xcode previews deterministic and offline instead of hitting the network at design time.
    static var mockPayload: WidgetPayload {
        (try? JSONDecoder.widgetPayload.decode(WidgetPayload.self, from: mockJSON)) ?? .empty
    }

    /// Timestamps are relative to `.now` (not hardcoded epoch values) so the fixture always
    /// exercises all three `dayLabel` states — today/tomorrow/future — regardless of when the
    /// preview is opened. "Deterministic" (see `mockPayload` above) means offline, not
    /// fixed-clock. Pinned to 7pm same-day so a preview opened near midnight can't push
    /// "today" into tomorrow's calendar date.
    ///
    /// Items 2 and 3 (the two rows that actually render a start time — item 1's "LIVE" caption
    /// hides its timestamp) are pinned to 2-digit 12-hour values (10pm, 12 noon) rather than
    /// reusing the 7pm base: a single-digit-only fixture is exactly how TimeBlockView's 2-digit
    /// hour clipping shipped unnoticed.
    private static var mockJSON: Data {
        let calendar = Calendar.current
        let base = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: .now) ?? .now
        let todayTS = Int(base.timeIntervalSince1970)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: base) ?? base
        let tomorrowTS = Int((calendar.date(bySettingHour: 22, minute: 0, second: 0, of: tomorrow) ?? tomorrow).timeIntervalSince1970)
        let future = calendar.date(byAdding: .day, value: 5, to: base) ?? base
        let futureTS = Int((calendar.date(bySettingHour: 12, minute: 0, second: 0, of: future) ?? future).timeIntervalSince1970)
        return Data("""
        {
          "schemaVersion": 2,
          "items": [
            {
              "id": "1", "mainText": "Fever @ Wings",
              "subText": "ESPN 263 · DirecTV",
              "caption": "LIVE", "emphasized": true, "timestamp": \(todayTS)
            },
            {
              "id": "2", "mainText": "Valkyries @ Sparks",
              "subText": "AMZN · Prime Video",
              "caption": null, "emphasized": false, "timestamp": \(tomorrowTS)
            },
            {
              "id": "3", "mainText": "Storm @ Mercury",
              "subText": "NBA TV · League Pass",
              "caption": null, "emphasized": false, "timestamp": \(futureTS)
            }
          ]
        }
        """.utf8)
    }
}

private extension WidgetPayload {
    static let empty = WidgetPayload(schemaVersion: 2, items: [])
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

// Plain TimelineProvider, not AppIntentTimelineProvider: the receiver has nothing to
// configure locally anymore (teams/sports move server-side, set from a browser), so
// there's no Edit Widget sheet to back — see docs/widget-config-plan.md.
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> GamesEntry {
        GamesEntry(date: .now, payload: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (GamesEntry) -> Void) {
        Task {
            let payload = await GameDataService.fetchPayload(context: context)
            completion(GamesEntry(date: .now, payload: payload))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GamesEntry>) -> Void) {
        Task {
            let payload = await GameDataService.fetchPayload(context: context)
            let entry = GamesEntry(date: .now, payload: payload)
            // Data doesn't change fast enough to justify burning the refresh budget more often
            // than this; retune if games start/finish mid-refresh-window.
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 60, to: .now)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh ?? .now.addingTimeInterval(3600))))
        }
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
/// a score. The server pre-formats `caption` ("LIVE"/"END") and decides `emphasized` for
/// the view-based contract; the one exception is the not-yet-started case, where the client
/// formats the raw `timestamp` itself so it respects the device's locale/24-hour setting.
private func displayCaption(for item: WidgetItem) -> (text: String, color: Color) {
    guard let caption = item.caption else {
        return (item.timestamp.formatted(date: .omitted, time: .shortened), .white.opacity(0.6))
    }
    return (caption, item.emphasized ? .red : .white.opacity(0.55))
}

/// "TODAY" gets a rich yellow + heavy weight to draw the eye; every other eyebrow value (e.g.
/// "TMRW", "AUG 16") stays the existing dim, lighter-weight treatment.
private func eyebrowStyle(for eyebrow: String) -> (color: Color, weight: Font.Weight) {
    eyebrow == "TODAY" ? (Color(red: 1.0, green: 0.78, blue: 0.0), .heavy) : (.white.opacity(0.8), .semibold)
}

/// Per-item day eyebrow, computed client-side from `timestamp` against the device's local
/// calendar — same rationale as `timeParts` below. Falls back to an abbreviated month/day
/// (e.g. "AUG 16") once a date is neither today nor tomorrow.
///
/// "TMRW", not "TOMORROW": the rail's fixed width means a longer string only fits via
/// `minimumScaleFactor`, which is an accessibility regression (shrinks the one word that
/// most needs to stay legible) rather than a real fix. Shortening the string lets it render
/// at full size; autosizing stays on as a safety net, not the primary mechanism.
private func dayLabel(for date: Date) -> String {
    let calendar = Calendar.autoupdatingCurrent
    if calendar.isDateInToday(date) { return "TODAY" }
    if calendar.isDateInTomorrow(date) { return "TMRW" }

    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.setLocalizedDateFormatFromTemplate("MMMd")
    return formatter.string(from: date).uppercased()
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

/// Tier of visual emphasis within the large layout's list: `.primary` is the first entry and
/// keeps every existing font/weight/color exactly as before; `.secondary` is every entry after
/// it, muted (not resized) so the first entry reads as clearly dominant.
private enum ItemTier {
    case primary
    case secondary
}

/// Steps a font weight down one notch for `.secondary` rows, leaving `.primary` untouched.
/// Used anywhere a tiered element must keep its exact size (the time rail's dimensions are
/// shared across every card) and can only signal tier via weight/opacity instead.
private func mutedWeight(_ weight: Font.Weight, tier: ItemTier) -> Font.Weight {
    guard tier == .secondary else { return weight }
    switch weight {
    case .black: return .semibold
    case .heavy: return .semibold
    case .semibold: return .regular
    default: return weight
    }
}

/// Trailing time display for the list layout: a large hour digit with minute/period stacked
/// beside it, mirroring a scoreboard clock. Falls back to `caption` (e.g. "LIVE"/"END") when
/// the game isn't in the not-yet-started state, same as displayCaption but laid out for a rail.
///
/// Dimensions (font sizes) are identical across tiers — the rail's footprint must line up card
/// to card. Tier reads purely through weight + opacity muting on `.secondary` rows.
private struct TimeBlockView: View {
    let item: WidgetItem
    var tier: ItemTier = .primary

    var body: some View {
        if let caption = item.caption {
            Text(caption)
                .font(.system(.title3, design: .rounded, weight: mutedWeight(.heavy, tier: tier)))
                .foregroundStyle((item.emphasized ? Color.red : Color.white.opacity(0.55)).opacity(tier == .primary ? 1 : 0.75))
        } else {
            let parts = timeParts(for: item.timestamp)
            // lineLimit + minimumScaleFactor are a safety net, not the primary fit mechanism —
            // ItemBlockView.timeBlockWidth is sized to fit a 2-digit hour ("10"/"11"/"12") at
            // the default text size without shrinking; this only catches larger Dynamic Type.
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(parts.hour)
                    .font(.system(.largeTitle, design: .monospaced, weight: mutedWeight(.black, tier: tier)))
                if let period = parts.period {
                    VStack(alignment: .leading, spacing: -2) {
                        Text(parts.minute)
                        Text(period)
                    }
                    .font(.system(.caption, design: .monospaced, weight: mutedWeight(.black, tier: tier)))
                } else {
                    Text(":\(parts.minute)")
                        .font(.system(.largeTitle, design: .monospaced, weight: mutedWeight(.black, tier: tier)))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(tier == .primary ? .white : .white.opacity(0.7))
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

    private var heroFont: Font {
        .system(.largeTitle, design: .default, weight: .black)
    }

    var body: some View {
        let caption = displayCaption(for: item)
        let eyebrow = dayLabel(for: item.timestamp)
        let eyebrowStyle = eyebrowStyle(for: eyebrow)
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.system(.caption2, design: .rounded, weight: eyebrowStyle.weight))
                .tracking(1.5)
                .foregroundStyle(eyebrowStyle.color)

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

/// One item's block within the medium/large list: a header row (matchup title baseline-aligned
/// against the time rail — both anchor to the same line the eye reads across — so a wrapped
/// second line grows upward instead of shifting the shared baseline down) plus a broadcast
/// line beneath. The broadcast line is centered and default-design (not monospaced, not
/// left-aligned like the title) precisely so it reads as a secondary, distinct element rather
/// than competing with the title for attention.
///
/// Title and time rail each get a dedicated fixed width instead of negotiating for space, so
/// the rail stays fully visible and a long title wraps in its own column rather than shoving
/// it out of view — also what makes wrapping resolvable at all inside AutoFitStack's
/// `.fixedSize()` pass, which proposes nil width here.
///
/// `rowWidth` is caller-supplied: large keeps `defaultRowWidth`, medium passes the widget's
/// actual available width so its single row spans it fully.
private struct ItemBlockView: View {
    let item: WidgetItem
    var rowWidth: CGFloat = Self.defaultRowWidth
    var tier: ItemTier = .primary

    // Confirmed (2026-08-20): Font.system(size:...) silently drops `design` here; only the
    // TextStyle-relative initializer threads it correctly. Default (sans), not monospaced —
    // that rationale is for the time rail's digits only.
    private var titleFont: Font {
        .system(tier == .primary ? .title : .title3, design: .default)
    }

    static let defaultRowWidth: CGFloat = 254
    // Fixed across tiers, not just primary: 64pt is tuned so dayLabel's longest values *and* a
    // 2-digit hour ("10"/"11"/"12", ~59pt measured on-device at the default text size) render
    // at full size (see the comment below); narrowing it for secondary rows would make the
    // minimumScaleFactor floor load-bearing instead of a safety net.
    private static let timeBlockWidth: CGFloat = 64
    private static let headerSpacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: Self.headerSpacing) {
                ItemLineView(text: item.mainText, font: titleFont, lineLimit: 2)
                    .frame(
                        width: rowWidth - Self.timeBlockWidth - Self.headerSpacing,
                        alignment: .leading
                    )
                    .fixedSize(horizontal: false, vertical: true)

                let eyebrow = dayLabel(for: item.timestamp)
                let eyebrowStyle = eyebrowStyle(for: eyebrow)
                VStack(alignment: .trailing, spacing: 2) {
                    // dayLabel's values ("TODAY"/"TMRW"/"AUG 16") are short enough to render
                    // at full size in 56pt; lineLimit + a scale floor stay on as a safety net
                    // for longer locale-specific month abbreviations, not the primary fit
                    // mechanism — shrinking this label by default would be an accessibility
                    // regression, not a fix.
                    Text(eyebrow)
                        .font(.system(.caption2, design: .rounded, weight: mutedWeight(eyebrowStyle.weight, tier: tier)))
                        .tracking(0.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(eyebrowStyle.color.opacity(tier == .primary ? 1 : 0.8))

                    TimeBlockView(item: item, tier: tier)
                }
                .frame(width: Self.timeBlockWidth, alignment: .trailing)
            }
            .frame(width: rowWidth, alignment: .leading)

            Text(item.subText)
                .font(.system(tier == .primary ? .title3 : .subheadline, design: .default, weight: .regular))
                .foregroundStyle(.white.opacity(tier == .primary ? 0.80 : 0.65))
                .lineLimit(2)
                .frame(width: rowWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Small, dim, corner-only — sized to register as "there's a refresh
/// affordance" without competing with the game data for attention. Runs
/// `RefreshWidgetIntent` in-process; no app launch on tap.
private struct RefreshButton: View {
    var body: some View {
        Button(intent: RefreshWidgetIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .padding(6)
                .background(Circle().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
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
                // `/config/resolve` never errors — an unpaired device still gets an
                // all-sports default (see docs/widget-config-plan.md) — so an empty
                // payload alone doesn't mean "not paired." `isPaired` is a local,
                // display-only cache: it only changes which copy renders here, never
                // whether the fetch above happens.
                VStack(spacing: 6) {
                    Image(systemName: DeviceIdentity.isPaired ? "sportscourt" : "person.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    if !DeviceIdentity.isPaired {
                        Text("Open the app to finish setup")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            } else if family == .systemSmall, let item = entry.payload.items.first {
                ItemHeroCard(item: item)
                    .padding(14)
            } else {
                let padding: CGFloat = 18
                GeometryReader { proxy in
                    // Large keeps the tuned fixed-width column; medium shows a single row, so
                    // give it the frame's real available width instead of large's column width.
                    let rowWidth = family == .systemMedium
                        ? proxy.size.width - padding * 2
                        : ItemBlockView.defaultRowWidth
                    // The refresh button lives in this ZStack, not inside the padded VStack
                    // below: AutoFitStack scales its content to fill exactly the padded area
                    // (min(widthScale, heightScale)), so a fully-packed large widget can reach
                    // every padded edge. Overlaying outside that padding puts the button in
                    // space that's guaranteed empty by construction, instead of risking it
                    // sitting on top of a game's broadcast line.
                    ZStack(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 10) {
                            AutoFitStack(spacing: family == .systemMedium ? 10 : 14) {
                                ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                                    if index == 1 {
                                        // The primary/secondary boundary reads as a visual break, not
                                        // another list separator: short, centered, and bright enough to
                                        // register at a glance, vs. the full-width dividers below it
                                        // which are doing information-based separation between rows.
                                        Rectangle()
                                            .fill(Color.white.opacity(0.4))
                                            .frame(width: rowWidth * 0.75, height: 2)
                                            .frame(width: rowWidth, alignment: .center)
                                    } else if index > 1 {
                                        // A system Divider() renders unpredictably under AutoFitStack's
                                        // scaleEffect; a plain rectangle scales reliably with everything else.
                                        Rectangle()
                                            .fill(Color.white.opacity(0.10))
                                            .frame(height: 1)
                                    }
                                    ItemBlockView(
                                        item: item,
                                        rowWidth: rowWidth,
                                        tier: index == 0 ? .primary : .secondary
                                    )
                                }
                            }
                            .foregroundStyle(.white)
                        }
                        .padding(padding)

                        RefreshButton()
                            .padding(6)
                    }
                }
            }
        }
        .containerBackground(.black, for: .widget)
    }
}

struct ClarkViewWidget: Widget {
    let kind: String = WidgetKind.main

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ClarkViewWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Games")
        .description("Shows upcoming games for your paired teams.")
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
