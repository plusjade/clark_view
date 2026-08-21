//
//  ClarkViewWidget.swift
//  ClarkViewWidget
//
//  Created by Jade Dominguez on 8/18/26.
//

import WidgetKit
import SwiftUI

private enum GameDataService {
    // TODO: Replace with a real fetch once the server exposes `?format=json`
    // (see discuss: schema-driven widget, 2026-08-20). Swap this function's
    // body for a URLSession/JSONDecoder call against GameImageURL and the
    // rest of the pipeline is unchanged.
    static func fetchGames(day: GameDay, teams: [FavoriteTeam]) async -> [Game] {
        mockGames
    }

    /// Synchronous so #Preview timeline blocks (which can't await) can use it too.
    static var mockGames: [Game] {
        (try? JSONDecoder.gameSchema.decode(GameSchema.self, from: mockJSON))?.games ?? []
    }

    private static let mockJSON = Data("""
    {
      "schemaVersion": 1,
      "day": "today",
      "games": [
        {
          "id": "1",
          "status": "live",
          "startTime": "2026-08-20T23:05:00Z",
          "away": { "id": "sparks", "abbreviation": "LAS", "name": "Sparks", "score": null, "colorHex": "#552583" },
          "home": { "id": "fever", "abbreviation": "IND", "name": "Fever", "score": null, "colorHex": "#FFC633" },
          "detail": null
        },
        {
          "id": "2",
          "status": "scheduled",
          "startTime": "2026-08-21T02:10:00Z",
          "away": { "id": "dodgers", "abbreviation": "LAD", "name": "Dodgers", "score": null, "colorHex": "#005A9C" },
          "home": { "id": "sf", "abbreviation": "SF", "name": "Giants", "score": null, "colorHex": "#FD5A1E" },
          "detail": null
        },
        {
          "id": "3",
          "status": "final",
          "startTime": "2026-08-20T20:00:00Z",
          "away": { "id": "warriors", "abbreviation": "GSW", "name": "Warriors", "score": null, "colorHex": "#1D428A" },
          "home": { "id": "lakers", "abbreviation": "LAL", "name": "Lakers", "score": null, "colorHex": "#552583" },
          "detail": null
        }
      ]
    }
    """.utf8)
}

private extension JSONDecoder {
    static let gameSchema: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

struct GamesEntry: TimelineEntry {
    let date: Date
    let day: GameDay
    let games: [Game]
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> GamesEntry {
        GamesEntry(date: .now, day: .today, games: [])
    }

    typealias Intent = ClarkViewWidgetConfigurationIntent

    func snapshot(for configuration: Intent, in context: Context) async -> GamesEntry {
        let games = await GameDataService.fetchGames(day: configuration.day, teams: configuration.teams)
        return GamesEntry(date: .now, day: configuration.day, games: games)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<GamesEntry> {
        let games = await GameDataService.fetchGames(day: configuration.day, teams: configuration.teams)
        let entry = GamesEntry(date: .now, day: configuration.day, games: games)
        // Data doesn't change fast enough to justify burning the refresh budget more often
        // than this; retune if games start/finish mid-refresh-window.
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 60, to: .now)
        return Timeline(entries: [entry], policy: .after(nextRefresh ?? .now.addingTimeInterval(3600)))
    }
}

/// Team name only — no score, no live clock. The widget's whole value proposition is
/// showing just "which of my teams, and when," not duplicating what every other sports
/// app already shows; see statusCaption below for the same principle applied to status.
private struct TeamLineView: View {
    let team: TeamScore
    let font: Font

    var body: some View {
        Text(team.name)
            .font(font)
            .lineLimit(1)
    }
}

/// Status stays a single word or a bare time — never the live-game clock/quarter, and never
/// a score. "LIVE"/"FINAL" tell you what you need (is it worth checking a real score tracker
/// right now?) without importing the noise this widget is deliberately not competing on.
private func statusCaption(for game: Game) -> (text: String, color: Color) {
    switch game.status {
    case .scheduled:
        (game.startTime.formatted(date: .omitted, time: .shortened), .white.opacity(0.6))
    case .live:
        ("LIVE", .red)
    case .final:
        ("FINAL", .white.opacity(0.55))
    }
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
/// than overflowing the frame. Generic over one game's two lines (small) or several games'
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

/// Small widget: one game, maximized. This is deliberately not a scaled-down version of the
/// multi-game layout below — small is a single-game "glance" case, so it gets its own
/// full-bleed template instead of being squeezed into the block layout medium/large share.
private struct HeroGameCard: View {
    let game: Game
    let day: GameDay

    private var heroFont: Font {
        .system(.largeTitle, design: .monospaced, weight: .black)
    }

    var body: some View {
        let status = statusCaption(for: game)
        VStack(alignment: .leading, spacing: 8) {
            Text(day.rawValue.uppercased())
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.5))

            AutoFitStack(spacing: 4) {
                TeamLineView(team: game.away, font: heroFont)
                TeamLineView(team: game.home, font: heroFont)
            }

            Text(status.text)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(status.color)
        }
        .foregroundStyle(.white)
    }
}

/// One game's block within the medium/large stack: two team-name lines + a status caption,
/// all measured and scaled together by the enclosing AutoFitStack so caption-to-name
/// proportions stay consistent as the shared scale grows or shrinks.
private struct GameBlockView: View {
    let game: Game

    // Confirmed (2026-08-20): any Font.system(size:...) construction silently drops `design`
    // in this widget's rendering pipeline, regardless of how weight is attached. Only the
    // TextStyle-relative initializer (.system(_:design:weight:)) threads `design` correctly
    // here — the reference tier only sets the *relative* size vs. the caption below; the
    // enclosing AutoFitStack rescales the whole block to fit anyway.
    private var nameFont: Font {
        .system(.title2, design: .monospaced, weight: .black)
    }

    var body: some View {
        let status = statusCaption(for: game)
        VStack(alignment: .leading, spacing: 2) {
            TeamLineView(team: game.away, font: nameFont)
            TeamLineView(team: game.home, font: nameFont)
            Text(status.text)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(status.color)
        }
    }
}

struct ClarkViewWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    private var visibleGames: [Game] {
        family == .systemMedium ? Array(entry.games.prefix(1)) : Array(entry.games.prefix(3))
    }

    var body: some View {
        Group {
            if entry.games.isEmpty {
                Image(systemName: "sportscourt")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            } else if family == .systemSmall, let game = entry.games.first {
                HeroGameCard(game: game, day: entry.day)
                    .padding(14)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.day.rawValue.uppercased())
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.5))
                    AutoFitStack(spacing: family == .systemMedium ? 10 : 14) {
                        ForEach(visibleGames) { game in
                            GameBlockView(game: game)
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
    GamesEntry(date: .now, day: .today, games: GameDataService.mockGames)
    GamesEntry(date: .now, day: .today, games: [])
}

#Preview(as: .systemMedium) {
    ClarkViewWidget()
} timeline: {
    GamesEntry(date: .now, day: .today, games: GameDataService.mockGames)
}

#Preview(as: .systemLarge) {
    ClarkViewWidget()
} timeline: {
    GamesEntry(date: .now, day: .today, games: GameDataService.mockGames)
}
