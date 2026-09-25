//
//  FocusWidgetItemIntent.swift
//  ClarkViewWidget
//

import AppIntents

/// Persists the item a person promoted in Beacon. WidgetKit reloads the timeline after
/// the intent returns, so the next entry can present that item as the large primary item.
struct FocusWidgetItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Focus Widget Item"

    @Parameter(title: "Item")
    var itemID: String

    @Parameter(title: "Change Focus")
    var changesFocus: Bool

    @Parameter(title: "Feed")
    var feedID: String

    init() {}

    init(itemID: String, changesFocus: Bool, feedID: String) {
        self.itemID = itemID
        self.changesFocus = changesFocus
        self.feedID = feedID
    }

    func perform() async throws -> some IntentResult {
        WidgetFocusStore.handleTap(on: itemID, in: feedID, changesFocus: changesFocus)
        return .result()
    }
}
