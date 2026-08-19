//
//  AppIntent.swift
//  ClarkViewWidget
//
//  Created by Jade Dominguez on 8/18/26.
//

import AppIntents
import WidgetKit

enum GameDay: String, AppEnum {
    case today
    case tomorrow

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Day" }
    static var caseDisplayRepresentations: [GameDay: DisplayRepresentation] {
        [
            .today: "Today",
            .tomorrow: "Tomorrow"
        ]
    }
}

struct FavoriteTeam: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Team" }
    static var defaultQuery = FavoriteTeamQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

// TODO: Backed by a hardcoded list until the server exposes `?format=teams`
// (see widget-config brief, 2026-08-18). Adding a team here means bumping the
// build number on both the app and widget extension and re-uploading; the
// server-side team table is meant to make that a val deploy instead.
struct FavoriteTeamQuery: EnumerableEntityQuery {
    static let all: [FavoriteTeam] = [
        FavoriteTeam(id: "sparks", name: "Sparks"),
        FavoriteTeam(id: "fever", name: "Fever"),
        FavoriteTeam(id: "dodgers", name: "Dodgers"),
        FavoriteTeam(id: "lakers", name: "Lakers"),
        FavoriteTeam(id: "warriors", name: "Warriors"),
        FavoriteTeam(id: "rams", name: "Rams"),
        FavoriteTeam(id: "panthers", name: "Panthers")
    ]

    func allEntities() async throws -> [FavoriteTeam] {
        Self.all
    }

    func entities(for identifiers: [FavoriteTeam.ID]) async throws -> [FavoriteTeam] {
        Self.all.filter { identifiers.contains($0.id) }
    }
}

struct ClarkViewWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Game Day" }
    static var description: IntentDescription { "Choose which day's games and favorite teams to show." }

    @Parameter(title: "Day", default: .today)
    var day: GameDay

    // Multi-select, favorites-only for v1 (no sports-toggle fallback yet).
    // Empty means no team filter — the server currently reads that as "all sports."
    @Parameter(
        title: "Favorite Teams",
        default: FavoriteTeamQuery.all.filter { $0.id == "sparks" || $0.id == "fever" },
        size: IntentCollectionSize(min: 0, max: 7)
    )
    var teams: [FavoriteTeam]

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$day)'s games for \(\.$teams)")
    }
}
