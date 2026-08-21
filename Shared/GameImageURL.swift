//
//  GameImageURL.swift
//  Shared
//
//  Created by Jade Dominguez on 8/19/26.
//

import Foundation

/// Builds request URLs for the game-image endpoint. Shared by the app and the
/// widget extension so the query-param contract only lives in one place.
enum GameImageURL {
    static let baseURL = URL(string: "https://plusjade--f0eeffb89a9311f19bb61607ee4eb77e.web.val.run/")!

    // Bumping the build number before each deploy changes this, so cached
    // responses (widget or app) get bypassed by a fresh generation.
    static let cacheBust = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    static func url(
        pixelWidth: Int,
        pixelHeight: Int,
        day: String,
        tzSecondsFromGMT: Int? = nil,
        teamIDs: [String] = []
    ) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "day", value: day),
            URLQueryItem(name: "format", value: "png"),
            // `size` is replacing the separate w=/h= pair; both are sent during
            // the rollout until the server only needs the combined form.
            URLQueryItem(name: "size", value: "\(pixelWidth)x\(pixelHeight)"),
            URLQueryItem(name: "w", value: String(pixelWidth)),
            URLQueryItem(name: "h", value: String(pixelHeight)),
            URLQueryItem(name: "v", value: cacheBust)
        ]
        if let tzSecondsFromGMT {
            // Seconds east of GMT, so the server can resolve today|tomorrow against
            // the device's local date instead of its own.
            queryItems.append(URLQueryItem(name: "tz", value: String(tzSecondsFromGMT)))
        }
        queryItems += teamIDs.map { URLQueryItem(name: "teams[]", value: $0) }
        components.queryItems = queryItems
        return components.url!
    }
}
