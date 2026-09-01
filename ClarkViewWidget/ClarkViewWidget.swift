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

    /// #Preview-only fixtures now that the live provider calls `fetchPayload` directly — keeps
    /// Xcode previews deterministic and offline instead of hitting the network at design time.
    /// Small/medium only ever render item 1, so they keep the "LIVE" state that's always been
    /// here; large's primary card is the one place that renders a not-yet-started primary item,
    /// so it gets `mockPayloadUpcoming` instead (see that property).
    static var mockPayload: WidgetPayload {
        (try? JSONDecoder.widgetPayload.decode(WidgetPayload.self, from: mockJSON(primaryCaption: "LIVE", primaryEmphasized: true))) ?? .empty
    }

    /// Same fixture, but item 1 (primary) has no caption, so `displayCaption`/`TimeBlockView`
    /// fall into the not-yet-started branch and format its `timestamp` instead of showing
    /// "LIVE" — lets the large layout's primary card preview an actual time.
    static var mockPayloadUpcoming: WidgetPayload {
        (try? JSONDecoder.widgetPayload.decode(WidgetPayload.self, from: mockJSON(primaryCaption: nil, primaryEmphasized: false))) ?? .empty
    }

    /// Timestamps are relative to `.now` (not hardcoded epoch values) so the fixture always
    /// exercises all three `dayLabel` states — today/tomorrow/future — regardless of when the
    /// preview is opened. "Deterministic" (see `mockPayload` above) means offline, not
    /// fixed-clock.
    ///
    /// Item 1 (primary) is pinned 2 hours out from whenever the preview opens, guaranteeing a
    /// not-yet-started time regardless of `primaryCaption` — so switching to
    /// `mockPayloadUpcoming` only changes whether that time is shown, not what it is.
    ///
    /// Items 2 and 3 are pinned to 7pm same-day as a `base`, not `.now`, so a preview opened
    /// near midnight can't push "today" into tomorrow's calendar date. They're pinned to
    /// 2-digit 12-hour values (10pm, 12 noon) rather than reusing the 7pm base directly: a
    /// single-digit-only fixture is exactly how TimeBlockView's 2-digit hour clipping shipped
    /// unnoticed.
    private static func mockJSON(primaryCaption: String?, primaryEmphasized: Bool) -> Data {
        let calendar = Calendar.current
        let primaryTS = Int(Date.now.addingTimeInterval(2 * 3600).timeIntervalSince1970)
        let base = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: .now) ?? .now
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: base) ?? base
        let tomorrowTS = Int((calendar.date(bySettingHour: 22, minute: 0, second: 0, of: tomorrow) ?? tomorrow).timeIntervalSince1970)
        let future = calendar.date(byAdding: .day, value: 5, to: base) ?? base
        let futureTS = Int((calendar.date(bySettingHour: 12, minute: 0, second: 0, of: future) ?? future).timeIntervalSince1970)
        let captionJSON = primaryCaption.map { "\"\($0)\"" } ?? "null"
        return Data("""
        {
          "schemaVersion": 2,
          "items": [
            {
              "id": "1", "mainText": "Fever @ Wings",
              "subText": "ESPN 263 · DirecTV",
              "caption": \(captionJSON), "emphasized": \(primaryEmphasized), "timestamp": \(primaryTS)
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
/// to a single line; the primary card raises it so long matchups can wrap.
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

/// Trailing time display: a scoreboard-style clock for the primary item and an inline clock
/// for secondary items. Falls back to `caption` (e.g. "LIVE"/"END") when the game isn't in
/// the not-yet-started state.
///
/// `.block` gives the primary item its scoreboard-style stack. `.compact` keeps the secondary
/// item's hour, minute, and period on one baseline to preserve vertical room for its content.
private struct TimeBlockView: View {
    enum Style {
        case block
        case compact
    }

    let item: WidgetItem
    var tier: ItemTier = .primary
    var style: Style = .block

    private var sizes: (hour: Font.TextStyle, minute: Font.TextStyle, caption: Font.TextStyle) {
        switch style {
        case .block: return (.largeTitle, .caption, .title3)
        case .compact: return (.title3, .caption, .subheadline)
        }
    }

    var body: some View {
        if let caption = item.caption {
            Text(caption)
                .font(.system(sizes.caption, design: .rounded, weight: mutedWeight(.heavy, tier: tier)))
                // No extra opacity multiplier for `.secondary` here (unlike the hour/minute
                // branch below): these two base colors are ~6:1 and ~5.9:1 against black on
                // their own — that's already the tier's entire contrast budget. `mutedWeight`
                // still carries the tier distinction via weight.
                .foregroundStyle(item.emphasized ? Color.red : Color.white.opacity(0.55))
        } else {
            let parts = timeParts(for: item.timestamp)
            // lineLimit + minimumScaleFactor are a safety net, not the primary fit mechanism —
            // ItemBlockView.timeBlockWidth is sized to fit a 2-digit hour ("10"/"11"/"12") at
            // the default text size without shrinking; this only catches larger Dynamic Type.
            Group {
                switch style {
                case .block:
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(parts.hour)
                            .font(.system(sizes.hour, design: .monospaced, weight: mutedWeight(.black, tier: tier)))
                        if let period = parts.period {
                            VStack(alignment: .leading, spacing: -2) {
                                Text(parts.minute)
                                Text(period)
                            }
                            .font(.system(sizes.minute, design: .monospaced, weight: mutedWeight(.black, tier: tier)))
                        } else {
                            Text(":\(parts.minute)")
                                .font(.system(sizes.hour, design: .monospaced, weight: mutedWeight(.black, tier: tier)))
                        }
                    }
                case .compact:
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(parts.hour)
                        Text(":\(parts.minute)")
                        if let period = parts.period {
                            Text(period)
                        }
                    }
                    .font(.system(sizes.minute, design: .monospaced, weight: mutedWeight(.black, tier: tier)))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(tier == .primary ? .white : .white.opacity(0.7))
            // The hour, minute, and period use separate Text views for their visual layouts,
            // so collapse them into one VoiceOver element with a properly formatted label.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.timestamp.formatted(date: .omitted, time: .shortened))
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

/// Applies one scale to both sections, then lets the space between them expand so their outer
/// edges stay pinned to the available frame. At the height-constrained scale, `minimumSpacing`
/// is the only gap; any extra height at the width-constrained scale becomes section spacing.
private struct AutoFitSplitStack<Top: View, Bottom: View>: View {
    let minimumSpacing: CGFloat
    @ViewBuilder let top: () -> Top
    @ViewBuilder let bottom: () -> Bottom

    @State private var naturalSize = StackSizeKey.defaultValue

    var body: some View {
        GeometryReader { proxy in
            let widthScale = proxy.size.width / max(naturalSize.width, 1)
            let heightScale = proxy.size.height / max(naturalSize.height, 1)
            let scale = min(widthScale, heightScale)
            let layoutWidth = proxy.size.width / max(scale, 0.001)
            let layoutHeight = proxy.size.height / max(scale, 0.001)

            VStack(alignment: .leading, spacing: 0) {
                top()
                    .fixedSize()

                Spacer(minLength: minimumSpacing)

                bottom()
                    .fixedSize()
            }
            .frame(width: layoutWidth, height: layoutHeight, alignment: .topLeading)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .background(
                VStack(alignment: .leading, spacing: minimumSpacing) {
                    top()
                    bottom()
                }
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

/// The primary item's card — the one thing the widget wants read first: a day/time row
/// (right-justified, on its own line — dayLabel and `TimeBlockView` sit side by side rather
/// than stacked, trading the vertical space a stacked pairing would cost for the row's own
/// height back), then the matchup title, then a broadcast line beneath — each spanning the
/// card's full width instead of sharing a row, so mainText and subText get the whole line for
/// their content rather than a column squeezed beside the time rail. The broadcast line is
/// centered and default-design (not monospaced, not left-aligned like the title) precisely so
/// it reads as a secondary, distinct element rather than competing with the title for
/// attention.
///
/// `rowWidth` is caller-supplied: large keeps `defaultRowWidth`, medium passes the widget's
/// actual available width so its single row spans it fully. Every other item in the large
/// layout uses `SecondaryItemRow` instead — this view is always tier `.primary`.
private struct ItemBlockView: View {
    let item: WidgetItem
    var rowWidth: CGFloat = Self.defaultRowWidth

    // Confirmed (2026-08-20): Font.system(size:...) silently drops `design` here; only the
    // TextStyle-relative initializer threads it correctly. Default (sans), not monospaced —
    // that rationale is for the time rail's digits only.
    private var titleFont: Font {
        .system(.title, design: .default)
    }

    static let defaultRowWidth: CGFloat = 254

    var body: some View {
        // 10pt, not the tight 2pt secondary rows use — this is the primary card's own share of
        // "give it more room," alongside the wider gap around the whole card in the caller.
        VStack(alignment: .leading, spacing: 10) {
            let eyebrow = dayLabel(for: item.timestamp)
            let eyebrowStyle = eyebrowStyle(for: eyebrow)
            HStack(alignment: .center, spacing: 6) {
                // dayLabel's values ("TODAY"/"TMRW"/"AUG 16") are short enough to render
                // at full size in 56pt; lineLimit + a scale floor stay on as a safety net
                // for longer locale-specific month abbreviations, not the primary fit
                // mechanism — shrinking this label by default would be an accessibility
                // regression, not a fix.
                Text(eyebrow)
                    .font(.system(.subheadline, design: .rounded, weight: eyebrowStyle.weight))
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(eyebrowStyle.color)

                TimeBlockView(item: item)
            }
            .frame(width: rowWidth, alignment: .trailing)

            ItemLineView(text: item.mainText, font: titleFont, lineLimit: 2)
                .frame(width: rowWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.subText)
                .font(.system(.title3, design: .default, weight: .regular))
                .foregroundStyle(.white.opacity(0.80))
                .lineLimit(2)
                .frame(width: rowWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Every item after the primary one, in the large layout: the same structural layout as
/// `ItemBlockView` — a day/time row (day label beside `TimeBlockView`, right-justified, on its
/// own line) then the matchup title on its own line, each spanning the row's full width — just
/// at `.compact` scale and without a subText line. This is the "everything else" glance,
/// deliberately smaller so it reads as a preview list rather than a second card competing with
/// the primary item.
///
/// Two deliberate departures from `ItemBlockView`, both secondary-only: the day/time row aligns
/// on `.lastTextBaseline` (vs. primary's `.center`), and mainText is right-justified instead of
/// left. The right-justified title is a left-to-right semantic, not just a visual one — primary
/// reads left-aligned because it's the active item; secondary rows read right-aligned because
/// they're the queue, not yet in play.
private struct SecondaryItemRow: View {
    let item: WidgetItem
    var rowWidth: CGFloat = ItemBlockView.defaultRowWidth

    var body: some View {
        let eyebrow = dayLabel(for: item.timestamp)
        let eyebrowStyle = eyebrowStyle(for: eyebrow)
        VStack(alignment: .trailing, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(eyebrow)
                    .font(.system(.caption2, design: .rounded, weight: mutedWeight(eyebrowStyle.weight, tier: .secondary)))
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(eyebrowStyle.color.opacity(0.8))

                TimeBlockView(item: item, tier: .secondary, style: .compact)
            }
            .frame(width: rowWidth, alignment: .trailing)

            ItemLineView(text: item.mainText, font: .system(.body, design: .default, weight: .semibold))
                .multilineTextAlignment(.trailing)
                .truncationMode(.tail)
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: rowWidth, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Corner-only, dim enough to stay out of the way of the game data — but sized to Apple's
/// 44×44pt HIG minimum tap target, not just a visually-small icon with padding around it.
/// Moving mainText/subText onto their own full-width lines (see `ItemBlockView`) freed up the
/// bottom-left corner this sits in, so the icon itself grew too, not just the hit area. Runs
/// `RefreshWidgetIntent` in-process; no app launch on tap.
private struct RefreshButton: View {
    var body: some View {
        Button(intent: RefreshWidgetIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

/// Presentation for a payload with no items; its copy stays injectable so the server can own it later.
private struct MissingItemsView: View {
    let message: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(spacing: 6) {
                Image(systemName: "sportscourt")
                    .font(.largeTitle)

                Text(message)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            RefreshButton()
                .padding(6)
        }
    }
}

/// Base backdrop for the widget: the tint color when the large layout has secondary items to
/// distinguish from primary, plain black otherwise (small, medium, empty state, a large with
/// just one item). This is deliberately *not* the dual-tone split itself — it's just the
/// secondary tone shown everywhere by default. The primary card carves out its own opaque black
/// region on top of this (see the `.background` attached to `ItemBlockView` below), so the two
/// tones never need to agree on a shared boundary computed twice in two different places.
///
/// The secondary rows render on top of this tint rather than pure black, which nudges their
/// contrast down slightly from the WCAG floor they were tuned against (roughly a 19% cut, e.g.
/// the "END"-style caption text goes from ~6.3:1 to ~5.1:1) — still clear of the 4.5:1 AA
/// minimum, just with less headroom than before. Worth a look if this tone gets any darker.
private struct WidgetBackground: View {
    var hasSecondaryItems: Bool

    //static let secondaryTone = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let secondaryTone = Color(red: 0, green: 0, blue: 0) // black

    var body: some View {
        hasSecondaryItems ? Self.secondaryTone : .black
    }
}

struct ClarkViewWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    private var visibleItems: [WidgetItem] {
        family == .systemMedium ? Array(entry.payload.items.prefix(1)) : Array(entry.payload.items.prefix(3))
    }

    private var hasSecondaryItems: Bool {
        family == .systemLarge && visibleItems.count > 1
    }

    var body: some View {
        Group {
            if entry.payload.items.isEmpty {
                MissingItemsView(message: "Nothing here right now 🫨")
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
                    // The refresh button lives in this ZStack, not inside the padded split layout
                    // below: AutoFitSplitStack scales its content to fill exactly the padded area
                    // (min(widthScale, heightScale)), so a fully-packed large widget can reach
                    // every padded edge. Overlaying outside that padding puts the button in
                    // space that's guaranteed empty by construction, instead of risking it
                    // sitting on top of a game's broadcast line.
                    let secondaryItems = visibleItems.dropFirst()
                    ZStack(alignment: .bottomLeading) {
                        // The primary and secondary sections share one scale, but flexible space
                        // between them absorbs unused height: primary stays at the top content edge
                        // while the secondary collection stays at the bottom content edge.
                        AutoFitSplitStack(minimumSpacing: secondaryItems.isEmpty ? 0 : 18) {
                            if let primary = visibleItems.first {
                                ItemBlockView(item: primary, rowWidth: rowWidth)
                                    .background {
                                        if !secondaryItems.isEmpty {
                                            // Negative padding bleeds this past its own content's
                                            // bounds toward the widget's true top/side edges. This
                                            // sits inside AutoFitSplitStack's scaleEffect, so it
                                            // deliberately overshoots rather than risking a sliver
                                            // of the secondary tone at a scaled edge.
                                            Color.black
                                                .padding(.top, -padding * 4)
                                                .padding(.horizontal, -padding * 4)
                                        }
                                    }
                            }
                        } bottom: {
                            if !secondaryItems.isEmpty {
                                VStack(alignment: .trailing, spacing: 10) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.4))
                                        .frame(width: rowWidth * 0.75, height: 0.5)

                                    // Condensed spacing is enough to read as a list; another
                                    // separator per row would compete with the section boundary.
                                    VStack(alignment: .trailing, spacing: 6) {
                                        ForEach(Array(secondaryItems), id: \.id) { item in
                                            SecondaryItemRow(item: item, rowWidth: rowWidth)
                                        }
                                    }
                                }
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(padding)

                        RefreshButton()
                            .padding(6)
                    }
                }
            }
        }
        .containerBackground(for: .widget) {
            WidgetBackground(hasSecondaryItems: hasSecondaryItems)
        }
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
    GamesEntry(date: .now, payload: GameDataService.mockPayloadUpcoming)
}
