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

private enum WidgetDataService {
    private static let cachedPayloadKey = "latestWidgetPayload"
    private static let cachedFeedIDKey = "latestWidgetPayloadFeedID"
    private static let cachedRevisionKey = "latestWidgetPayloadRevision"
    private static let defaults = UserDefaults(suiteName: DeviceIdentity.appGroupID) ?? .standard

    static func fetchPayload(context: Provider.Context) async -> WidgetPayload {
        guard let feed = FeedSelection.current else { return .empty }
        let revision = FeedSelection.revision
        if WidgetFocusStore.shouldReuseCachedPayload, let cachedPayload = cachedPayload(for: feed) {
            return cachedPayload
        }

        WidgetRefreshDiagnostics.recordAttempt()
        do {
            let (payload, data) = try await FeedDirectoryClient.payloadWithData(for: feed)
            guard FeedSelection.current?.id == feed.id, FeedSelection.revision == revision else { return .empty }
            defaults.set(data, forKey: cachedPayloadKey)
            defaults.set(feed.id, forKey: cachedFeedIDKey)
            defaults.set(revision, forKey: cachedRevisionKey)
            WidgetRefreshDiagnostics.recordSuccess()
            return payload
        } catch {
            guard FeedSelection.revision == revision else { return .empty }
            let message = error is DecodingError
                ? "Invalid widget response"
                : error.localizedDescription
            WidgetRefreshDiagnostics.recordFailure(message)
            return .empty
        }
    }

    private static func cachedPayload(for feed: Feed) -> WidgetPayload? {
        guard defaults.string(forKey: cachedFeedIDKey) == feed.id,
              defaults.string(forKey: cachedRevisionKey) == FeedSelection.revision,
              let data = defaults.data(forKey: cachedPayloadKey) else {
            return nil
        }
        return try? JSONDecoder.widgetPayload.decode(WidgetPayload.self, from: data)
    }

    /// #Preview-only fixtures now that the live provider calls `fetchPayload` directly — keeps
    /// Xcode previews deterministic and offline instead of hitting the network at design time.
    /// Small/medium only ever render item 1, so they keep the "LIVE" state that's always been
    /// here; large's primary card is the one place that renders a not-yet-started primary item,
    /// so it gets `mockPayloadUpcoming` instead (see that property).
    static var mockPayload: WidgetPayload {
        (try? JSONDecoder.widgetPayload.decode(WidgetPayload.self, from: mockJSON(primaryIsCurrent: true))) ?? .empty
    }

    /// Same fixture, but item 1 (primary) hasn't started, so it resolves to the feed's
    /// `upcoming` label — null — and the view formats its `startsAt` instead of showing
    /// "LIVE". Lets the large layout's primary card preview an actual time.
    static var mockPayloadUpcoming: WidgetPayload {
        (try? JSONDecoder.widgetPayload.decode(WidgetPayload.self, from: mockJSON(primaryIsCurrent: false))) ?? .empty
    }

    /// Start times are relative to `.now` (not hardcoded epoch values) so the fixture always
    /// exercises all three `dayLabel` states — today/tomorrow/future — regardless of when the
    /// preview is opened. "Deterministic" (see `mockPayload` above) means offline, not
    /// fixed-clock.
    ///
    /// Item 4 carries a one-second window, the shape of an instantaneous event,
    /// takes on the wire, so a decoded preview payload is never all hours-long items.
    ///
    /// Item 1 (primary) is the only one whose window moves: `primaryIsCurrent` puts it either
    /// mid-window (so it resolves to "LIVE") or two hours out (so it resolves to a clock
    /// time). Since the label now comes from the window, a fixture cannot preview "LIVE" on an
    /// item that hasn't started — which is the point.
    ///
    /// Items 2 and 3 are pinned to 7pm same-day as a `base`, not `.now`, so a preview opened
    /// near midnight can't push "today" into tomorrow's calendar date. They're pinned to
    /// 2-digit 12-hour values (10pm, 12 noon) rather than reusing the 7pm base directly, so a
    /// single-digit-only fixture can't hide a 2-digit hour rendering regression.
    private static func mockJSON(primaryIsCurrent: Bool) -> Data {
        let calendar = Calendar.current
        let primaryStart = Date.now.addingTimeInterval(primaryIsCurrent ? -30 * 60 : 2 * 3600)
        let primaryTS = Int(primaryStart.timeIntervalSince1970)
        let base = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: .now) ?? .now
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: base) ?? base
        let tomorrowTS = Int((calendar.date(bySettingHour: 22, minute: 0, second: 0, of: tomorrow) ?? tomorrow).timeIntervalSince1970)
        let future = calendar.date(byAdding: .day, value: 5, to: base) ?? base
        let futureTS = Int((calendar.date(bySettingHour: 12, minute: 0, second: 0, of: future) ?? future).timeIntervalSince1970)
        return Data("""
        {
          "schemaVersion": 3,
          "presentation": {
            "version": 2,
            "template": "beacon",
            "rootSurface": {
              "light": "#14213D",
              "dark": "#261447"
            }
          },
          "lifecycle": { "upcoming": null, "current": "LIVE", "expired": "END" },
          "items": [
            {
              "id": "1", "mainText": "Fever @ Wings",
              "subText": "ESPN 263 · DirecTV",
              "startsAt": \(primaryTS), "expiresAt": \(primaryTS + 7200)
            },
            {
              "id": "2", "mainText": "Valkyries @ Sparks",
              "subText": "AMZN · Prime Video",
              "startsAt": \(tomorrowTS), "expiresAt": \(tomorrowTS + 7200)
            },
            {
              "id": "3", "mainText": "Storm @ Mercury",
              "subText": "NBA TV · League Pass",
              "startsAt": \(futureTS), "expiresAt": \(futureTS + 7200)
            },
            {
              "id": "4", "mainText": "Eclipse Peak",
              "subText": "Total eclipse",
              "startsAt": \(futureTS), "expiresAt": \(futureTS + 1)
            }
          ]
        }
        """.utf8)
    }
}

private extension WidgetPayload {
    static let empty = WidgetPayload(schemaVersion: 3, items: [])
}

private extension JSONDecoder {
    static let widgetPayload: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()
}

struct WidgetEntry: TimelineEntry {
    let date: Date
    let payload: WidgetPayload
    let focusedItemID: String?
    let selectionRevision: String
    let feedID: String?

    init(date: Date, payload: WidgetPayload, focusedItemID: String? = nil,
         selectionRevision: String = FeedSelection.revision) {
        self.date = date
        self.payload = payload
        self.focusedItemID = focusedItemID
        self.selectionRevision = selectionRevision
        self.feedID = FeedSelection.current?.id
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: .now, payload: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        if context.isPreview {
            completion(WidgetEntry(date: .now, payload: WidgetDataService.mockPayload))
            return
        }
        Task {
            let revision = FeedSelection.revision
            let payload = await WidgetDataService.fetchPayload(context: context)
            let currentPayload = revision == FeedSelection.revision ? payload : .empty
            completion(WidgetEntry(
                date: .now,
                payload: currentPayload,
                focusedItemID: WidgetFocusStore.focusedItemID,
                selectionRevision: revision
            ))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        Task {
            let revision = FeedSelection.revision
            let payload = await WidgetDataService.fetchPayload(context: context)
            let currentPayload = revision == FeedSelection.revision ? payload : .empty
            let now = Date.now
            let focusedItemID = WidgetFocusStore.focusedItemID
            // One entry now, then one at every later bound. The payload is identical across
            // them — only the entry's date differs, which is what moves each item to its next
            // lifecycle label without another fetch.
            let entries = ([now] + lifecycleEntryDates(for: currentPayload, after: now)).map {
                WidgetEntry(date: $0, payload: currentPayload, focusedItemID: focusedItemID,
                            selectionRevision: revision)
            }
            // The next moment any item's wording can change is one of its own bounds, so the
            // reload is asked for then rather than an hour later. Absent a bound in the next
            // hour this is still the hourly refresh it always was.
            completion(Timeline(entries: entries, policy: .after(nextRefreshDate(for: currentPayload))))
        }
    }
}

extension Color {
    init(srgb color: WidgetSRGBColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: 1)
    }
}

struct ClarkViewWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: Provider.Entry

    private var destinationURL: URL? {
        let focused = entry.focusedItemID.flatMap { id in entry.payload.items.first { $0.id == id } }
        guard let item = focused ?? entry.payload.items.first else { return nil }
        return AppDeepLink(
            kind: .event,
            subjectID: item.id,
            title: item.mainText,
            detail: item.subText,
            startsAt: item.startsAt
        ).url
    }

    var body: some View {
        if entry.selectionRevision != FeedSelection.revision {
            Text("Choose feed in Clark View")
        } else if FeedSelection.isUnavailable {
            Text("Feed unavailable. Choose a feed in Clark View.")
        } else if family == .accessoryRectangular {
            BeaconLockScreenView(entry: entry)
                .widgetURL(destinationURL)
        } else {
            let presentation = WidgetPresentation(payload: entry.payload.presentation)
            BeaconWidgetTemplate(entry: entry, presentation: presentation)
                .widgetURL(destinationURL)
        }
    }
}

struct ClarkViewWidget: Widget {
    let kind: String = WidgetKind.main

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ClarkViewWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Clark View")
        .description("Shows upcoming items from your paired sources.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
        .contentMarginsDisabled()
        .pushHandler(ClarkViewWidgetPushHandler.self)
    }
}

#Preview(as: .systemSmall) {
    ClarkViewWidget()
} timeline: {
    WidgetEntry(date: .now, payload: WidgetDataService.mockPayload)
    WidgetEntry(date: .now, payload: .empty)
}

#Preview(as: .systemMedium) {
    ClarkViewWidget()
} timeline: {
    WidgetEntry(date: .now, payload: WidgetDataService.mockPayload)
}

#Preview(as: .systemLarge) {
    ClarkViewWidget()
} timeline: {
    WidgetEntry(date: .now, payload: WidgetDataService.mockPayloadUpcoming)
}

#Preview("Lock Screen", as: .accessoryRectangular) {
    ClarkViewWidget()
} timeline: {
    WidgetEntry(date: .now, payload: WidgetDataService.mockPayload)
    WidgetEntry(date: .now, payload: WidgetDataService.mockPayloadUpcoming)
    WidgetEntry(date: .now, payload: .empty)
    WidgetEntry(date: .now, payload: WidgetPayload(schemaVersion: 3, items: [
        WidgetItem(
            id: "long", mainText: "A very long event title with multiple participants",
            subText: "An extended source and broadcast description",
            startsAt: .now.addingTimeInterval(86_400),
            expiresAt: .now.addingTimeInterval(86_400 + 7_200)
        )
    ]))
}
