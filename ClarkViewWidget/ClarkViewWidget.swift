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

    static func url(pixelWidth: Int, pixelHeight: Int) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "day", value: "today"),
            URLQueryItem(name: "games", value: "10"),
            URLQueryItem(name: "format", value: "png"),
            URLQueryItem(name: "w", value: String(pixelWidth)),
            URLQueryItem(name: "h", value: String(pixelHeight))
        ]
        return components.url!
    }

    static func fetchImageData(displaySize: CGSize, scale: CGFloat) async -> Data? {
        let pixelWidth = Int((displaySize.width * scale).rounded())
        let pixelHeight = Int((displaySize.height * scale).rounded())
        let request = URLRequest(
            url: url(pixelWidth: pixelWidth, pixelHeight: pixelHeight),
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

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> GameImageEntry {
        GameImageEntry(date: .now, imageData: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (GameImageEntry) -> Void) {
        let scale = UIScreen.main.scale
        Task {
            let data = await GameImageService.fetchImageData(displaySize: context.displaySize, scale: scale)
            completion(GameImageEntry(date: .now, imageData: data))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GameImageEntry>) -> Void) {
        let scale = UIScreen.main.scale
        Task {
            let data = await GameImageService.fetchImageData(displaySize: context.displaySize, scale: scale)
            let entry = GameImageEntry(date: .now, imageData: data)
            // "day=today" data doesn't change fast enough to justify burning the refresh budget more
            // often than this; retune if games start/finish mid-refresh-window.
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 60, to: .now)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh ?? .now.addingTimeInterval(3600))))
        }
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
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ClarkViewWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Games")
        .description("Shows today's games.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    ClarkViewWidget()
} timeline: {
    GameImageEntry(date: .now, imageData: nil)
}
