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
    private static let defaults = UserDefaults(suiteName: DeviceIdentity.appGroupID) ?? .standard

    private static func cacheKey(for feedID: String) -> String {
        "latestWidgetPayload:" + Data(feedID.utf8).base64EncodedString()
    }

    static func fetchPayload(for feed: Feed?, context: FeedRequestContext) async -> WidgetFetchResult {
        guard !Task.isCancelled else { return WidgetFetchResult(payload: .empty) }
        guard let feed else { return WidgetFetchResult(payload: .empty) }
        if WidgetFocusStore.shouldReuseCachedPayload(for: feed.id),
           let cachedPayload = cachedPayload(for: feed.id) {
            return WidgetFetchResult(payload: cachedPayload)
        }

        WidgetRefreshDiagnostics.recordAttempt()
        do {
            let (payload, data) = try await FeedDirectoryClient.payloadWithData(for: feed, context: context)
            guard !Task.isCancelled else { return WidgetFetchResult(payload: .empty) }
            defaults.set(data, forKey: cacheKey(for: feed.id))
            WidgetRefreshDiagnostics.recordSuccess()
            return WidgetFetchResult(payload: payload)
        } catch {
            guard !Task.isCancelled else { return WidgetFetchResult(payload: .empty) }
            if (error as? FeedClientError) == .unavailable {
                clearCachedPayload(for: feed.id)
            }
            let message = error is DecodingError
                ? "Invalid widget response"
                : error.localizedDescription
            WidgetRefreshDiagnostics.recordFailure(message)
            return WidgetFetchResult(payload: .empty, unavailable: (error as? FeedClientError) == .unavailable)
        }
    }

    private static func cachedPayload(for feedID: String) -> WidgetPayload? {
        guard let data = defaults.data(forKey: cacheKey(for: feedID)) else { return nil }
        return try? JSONDecoder.widgetPayload.decode(WidgetPayload.self, from: data)
    }

    private static func clearCachedPayload(for feedID: String) {
        defaults.removeObject(forKey: cacheKey(for: feedID))
        WidgetFocusStore.clear(for: feedID)
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

private extension FeedRequestContext {
    static func widget(_ family: WidgetFamily, purpose: String) -> FeedRequestContext {
        FeedRequestContext(caller: "widget", family: family.inventoryName, purpose: purpose)
    }
}

private struct WidgetFetchResult {
    let payload: WidgetPayload
    var unavailable = false
}

/// Captures the configured feed for a widget timeline and its focus actions.
struct WidgetFeedContext {
    let feed: Feed?

    init(configuration: WidgetFeedIntent) {
        feed = configuration.feed.map { Feed(id: $0.id, name: $0.name) }
    }

    static var preview: WidgetFeedContext {
        WidgetFeedContext(feed: Feed(id: "preview", name: "Preview"))
    }

    private init(feed: Feed?) {
        self.feed = feed
    }
}

struct WidgetEntry: TimelineEntry {
    let date: Date
    let payload: WidgetPayload
    let focusedItemID: String?
    let feedContext: WidgetFeedContext
    let unavailable: Bool

    init(date: Date, payload: WidgetPayload, focusedItemID: String? = nil,
         feedContext: WidgetFeedContext = .preview, unavailable: Bool = false) {
        self.date = date
        self.payload = payload
        self.focusedItemID = focusedItemID
        self.feedContext = feedContext
        self.unavailable = unavailable
    }
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: .now, payload: .empty)
    }

    func snapshot(for configuration: WidgetFeedIntent, in context: Context) async -> WidgetEntry {
        if context.isPreview {
            return WidgetEntry(date: .now, payload: WidgetDataService.mockPayload)
        }
        let selection = WidgetFeedContext(configuration: configuration)
        let result = await WidgetDataService.fetchPayload(for: selection.feed,
                                                          context: .widget(context.family, purpose: "snapshot"))
        return WidgetEntry(date: .now, payload: result.payload,
                           focusedItemID: selection.feed.flatMap { WidgetFocusStore.focusedItemID(for: $0.id) },
                           feedContext: selection, unavailable: result.unavailable)
    }

    func timeline(for configuration: WidgetFeedIntent, in context: Context) async -> Timeline<WidgetEntry> {
        let selection = WidgetFeedContext(configuration: configuration)
        // Every timeline reports, including unconfigured and cache-reuse paths; the reporter
        // bounds itself so it never delays the timeline past its own deadline.
        async let inventory: Void = WidgetInventoryReporter.shared.report(trigger: .timeline)
        let result = await WidgetDataService.fetchPayload(for: selection.feed,
                                                          context: .widget(context.family, purpose: "timeline"))
        await inventory
        let payload = result.payload
        let now = Date.now
        let focusedItemID = selection.feed.flatMap { WidgetFocusStore.focusedItemID(for: $0.id) }
        // One entry now, then one at every later bound. The payload is identical across
        // them — only the entry's date differs, which moves lifecycle wording without a fetch.
        let entries = ([now] + lifecycleEntryDates(for: payload, after: now)).map {
            WidgetEntry(date: $0, payload: payload, focusedItemID: focusedItemID,
                        feedContext: selection, unavailable: result.unavailable)
        }
        return Timeline(entries: entries, policy: .after(nextRefreshDate(for: payload)))
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
        if entry.feedContext.feed == nil {
            WidgetMessageView(text: "Long Press\n→ Edit Widget\n→ Choose Feed")
        } else if entry.unavailable {
            WidgetMessageView(text: "Feed unavailable\nlong press to edit widget & choose another.")
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

/// Status text for unconfigured or unavailable feeds; every widget view needs a container background.
private struct WidgetMessageView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct ClarkViewWidget: Widget {
    let kind: String = WidgetKind.configurable

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WidgetFeedIntent.self, provider: Provider()) { entry in
            ClarkViewWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Clark View")
        .description("Choose a feed for this widget. Selection does not subscribe to notifications.")
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
