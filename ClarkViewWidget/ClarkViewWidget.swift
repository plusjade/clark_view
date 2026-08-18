//
//  ClarkViewWidget.swift
//  ClarkViewWidget
//
//  Created by Jade Dominguez on 8/18/26.
//

import WidgetKit
import SwiftUI
import UIKit

private enum GameImageService {
    static let baseURL = URL(string: "https://plusjade--f0eeffb89a9311f19bb61607ee4eb77e.web.val.run/")!

    // Bumping the build number before each deploy changes this, so widgets on
    // devices pick up a fresh generation instead of a stale cached response.
    static let cacheBust = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    static func url(pixelWidth: Int, pixelHeight: Int, day: GameDay) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "day", value: day.rawValue),
            URLQueryItem(name: "format", value: "png"),
            URLQueryItem(name: "w", value: String(pixelWidth)),
            URLQueryItem(name: "h", value: String(pixelHeight)),
            URLQueryItem(name: "v", value: cacheBust)
        ]
        return components.url!
    }

    static func fetchImageData(displaySize: CGSize, scale: CGFloat, day: GameDay) async -> Data? {
        let pixelWidth = Int((displaySize.width * scale).rounded())
        let pixelHeight = Int((displaySize.height * scale).rounded())
        let request = URLRequest(
            url: url(pixelWidth: pixelWidth, pixelHeight: pixelHeight, day: day),
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }
}

struct GameImageEntry: TimelineEntry {
    let date: Date
    let imageData: Data?
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> GameImageEntry {
        GameImageEntry(date: .now, imageData: nil)
    }

    typealias Intent = ClarkViewWidgetConfigurationIntent

    func snapshot(for configuration: Intent, in context: Context) async -> GameImageEntry {
        let scale = await UIScreen.main.scale
        let data = await GameImageService.fetchImageData(
            displaySize: context.displaySize, scale: scale, day: configuration.day
        )
        return GameImageEntry(date: .now, imageData: data)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<GameImageEntry> {
        let scale = await UIScreen.main.scale
        let data = await GameImageService.fetchImageData(
            displaySize: context.displaySize, scale: scale, day: configuration.day
        )
        let entry = GameImageEntry(date: .now, imageData: data)
        // Data doesn't change fast enough to justify burning the refresh budget more often
        // than this; retune if games start/finish mid-refresh-window.
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 60, to: .now)
        return Timeline(entries: [entry], policy: .after(nextRefresh ?? .now.addingTimeInterval(3600)))
    }
}

struct ClarkViewWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        Group {
            if let data = entry.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                Image(systemName: "sportscourt")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
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
    GameImageEntry(date: .now, imageData: nil)
}
