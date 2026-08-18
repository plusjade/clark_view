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

struct ClarkViewWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Game Day" }
    static var description: IntentDescription { "Choose which day's games to show." }

    @Parameter(title: "Day", default: .today)
    var day: GameDay
}
