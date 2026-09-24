//
//  ServerURL.swift
//  Shared
//
//  Created by Jade Dominguez on 8/19/26.
//

import Foundation

/// Stable Val Town endpoint for installation operations and public feed reads.
enum ServerURL {
    static let baseURL = URL(string: "https://plusjade--f0eeffb89a9311f19bb61607ee4eb77e.web.val.run/")!

    static var feedsURL: URL { baseURL.appendingPathComponent("feeds") }

    static func installationFeedURL(_ installationID: String) -> URL {
        baseURL.appendingPathComponent("installations").appendingPathComponent(installationID)
            .appendingPathComponent("feed")
    }

    static func feedURL(_ feedID: String, timeZoneIdentifier: String) -> URL {
        var components = URLComponents(url: feedsURL.appendingPathComponent(feedID), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "timeZone", value: timeZoneIdentifier)]
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url!
    }

}
