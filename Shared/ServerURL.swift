//
//  ServerURL.swift
//  Shared
//
//  Created by Jade Dominguez on 8/19/26.
//

import Foundation

/// The shared Val Town backend base URL, used by every client (pairing, push token,
/// device status, alerts) to build its own endpoint. `resolveURL` additionally builds
/// the widget's one outbound request: `GET /config/resolve` returns the schema-v2
/// payload directly, with no redirect.
enum ServerURL {
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
