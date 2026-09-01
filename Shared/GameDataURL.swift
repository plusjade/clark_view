//
//  GameDataURL.swift
//  Shared
//
//  Created by Jade Dominguez on 8/19/26.
//

import Foundation

/// Builds the widget's one outbound request. `/config/resolve` 302s to the
/// real data URL; `URLSession` follows redirects transparently, so this is still a
/// single round trip. Shared by the app and the widget extension so the one
/// remaining query-param contract only lives in one place.
enum GameDataURL {
    static let baseURL = URL(string: "https://plusjade--f0eeffb89a9311f19bb61607ee4eb77e.web.val.run/")!

    static func resolveURL(device: String, pixelWidth: Int, pixelHeight: Int, tzSecondsFromGMT: Int) -> URL {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("config/resolve"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "device", value: device),
            URLQueryItem(name: "d", value: "\(pixelWidth)x\(pixelHeight)"),
            // Seconds east of GMT — what `/config/resolve` resolves "today"/"tomorrow"
            // against on the server, same as the old jsonURL's `tz`.
            URLQueryItem(name: "tz", value: String(tzSecondsFromGMT))
        ]
        return components.url!
    }
}
