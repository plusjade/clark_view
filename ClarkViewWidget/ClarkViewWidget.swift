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
    private static let defaults = UserDefaults(suiteName: DeviceIdentity.appGroupID) ?? .standard

    static func fetchPayload(context: Provider.Context) async -> WidgetPayload {
        if WidgetFocusStore.shouldReuseCachedPayload, let cachedPayload {
            return cachedPayload
        }

        WidgetRefreshDiagnostics.recordAttempt()
        let scale = UITraitCollection.current.displayScale
        let pixelWidth = Int((context.displaySize.width * scale).rounded())
        let pixelHeight = Int((context.displaySize.height * scale).rounded())
        let request = URLRequest(
            url: ServerURL.resolveURL(
                device: DeviceIdentity.deviceID,
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight,
                tzSecondsFromGMT: TimeZone.current.secondsFromGMT()
            ),
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                WidgetRefreshDiagnostics.recordFailure("Invalid server response")
                return .empty
            }
            guard httpResponse.statusCode == 200 else {
                WidgetRefreshDiagnostics.recordFailure("Server returned HTTP \(httpResponse.statusCode)")
                return .empty
            }
            let payload = try JSONDecoder.widgetPayload.decode(WidgetPayload.self, from: data)
            defaults.set(data, forKey: cachedPayloadKey)
            WidgetRefreshDiagnostics.recordSuccess()
            return payload
        } catch {
            let message = error is DecodingError
                ? "Invalid widget response"
                : error.localizedDescription
            WidgetRefreshDiagnostics.recordFailure(message)
            return .empty
        }
    }

    private static var cachedPayload: WidgetPayload? {
        guard let data = defaults.data(forKey: cachedPayloadKey) else {
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
        (try? JSONDecoder.widgetPayload.decode(WidgetPayload.self, from: mockJSON(primaryCaption: "LIVE", primaryEmphasized: true))) ?? .empty
    }

    /// Same fixture, but item 1 (primary) has no caption, so the not-yet-started branch formats
    /// its `timestamp` instead of showing "LIVE" — lets the large layout's primary card preview
    /// an actual time.
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
    /// 2-digit 12-hour values (10pm, 12 noon) rather than reusing the 7pm base directly, so a
    /// single-digit-only fixture can't hide a 2-digit hour rendering regression.
    private static func mockJSON(
        primaryCaption: String?,
        primaryEmphasized: Bool
    ) -> Data {
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
          "presentation": {
            "version": 2,
            "template": "beacon",
            "rootSurface": {
              "light": "#14213D",
              "dark": "#261447"
            }
          },
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

struct WidgetEntry: TimelineEntry {
    let date: Date
    let payload: WidgetPayload
    let focusedItemID: String?

    init(date: Date, payload: WidgetPayload, focusedItemID: String? = nil) {
        self.date = date
        self.payload = payload
        self.focusedItemID = focusedItemID
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
            let payload = await WidgetDataService.fetchPayload(context: context)
            completion(WidgetEntry(
                date: .now,
                payload: payload,
                focusedItemID: WidgetFocusStore.focusedItemID
            ))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        Task {
            let payload = await WidgetDataService.fetchPayload(context: context)
            let entry = WidgetEntry(
                date: .now,
                payload: payload,
                focusedItemID: WidgetFocusStore.focusedItemID
            )
            // Data doesn't change fast enough to justify burning the refresh budget more often
            // than this; retune if items start/finish mid-refresh-window.
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 60, to: .now)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh ?? .now.addingTimeInterval(3600))))
        }
    }
}

extension Color {
    init(srgb color: WidgetSRGBColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: 1)
    }
}

/// Per-item day eyebrow, computed client-side from `timestamp` against the device's local
/// calendar — same rationale as `timeParts` below. Falls back to an abbreviated month/day
/// (e.g. "AUG 16") once a date is neither today nor tomorrow.
///
/// "TMRW", not "TOMORROW": the rail's fixed width means a longer string only fits via
/// `minimumScaleFactor`, which is an accessibility regression (shrinks the one word that
/// most needs to stay legible) rather than a real fix. Shortening the string lets it render
/// at full size; autosizing stays on as a safety net, not the primary mechanism.
func dayLabel(for date: Date) -> String {
    let calendar = Calendar.autoupdatingCurrent
    if calendar.isDateInToday(date) { return "TODAY" }
    if calendar.isDateInTomorrow(date) { return "TMRW" }

    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.setLocalizedDateFormatFromTemplate("MMMd")
    return formatter.string(from: date).uppercased()
}

struct ClarkViewWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: Provider.Entry

    var body: some View {
        if family == .accessoryRectangular {
            BeaconLockScreenView(entry: entry)
        } else {
            let presentation = WidgetPresentation(payload: entry.payload.presentation)
            BeaconWidgetTemplate(entry: entry, presentation: presentation)
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
    WidgetEntry(date: .now, payload: WidgetPayload(schemaVersion: 2, items: [
        WidgetItem(
            id: "long", mainText: "A very long event title with multiple participants",
            subText: "An extended source and broadcast description",
            caption: nil, emphasized: false, timestamp: .now.addingTimeInterval(86_400)
        )
    ]))
}
