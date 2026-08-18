//
//  ContentView.swift
//  clark_view
//
//  Created by Jade Dominguez on 8/18/26.
//

import SwiftUI

private enum GameImageURLBuilder {
    static let baseURL = URL(string: "https://plusjade--f0eeffb89a9311f19bb61607ee4eb77e.web.val.run/")!

    // Kept in sync with ClarkViewWidget/ClarkViewWidget.swift's cache-bust logic.
    static let cacheBust = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    static func url(pixelWidth: Int, pixelHeight: Int) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "day", value: "today"),
            URLQueryItem(name: "format", value: "png"),
            URLQueryItem(name: "w", value: String(pixelWidth)),
            URLQueryItem(name: "h", value: String(pixelHeight)),
            URLQueryItem(name: "v", value: cacheBust)
        ]
        return components.url!
    }
}

struct ContentView: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            let pixelWidth = Int((geometry.size.width * displayScale).rounded())
            let pixelHeight = Int((geometry.size.height * displayScale).rounded())

            AsyncImage(url: GameImageURLBuilder.url(pixelWidth: pixelWidth, pixelHeight: pixelHeight)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "sportscourt")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                default:
                    ProgressView()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }
}

#Preview {
    ContentView()
}
