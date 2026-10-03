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

    static func feedURL(_ feedID: String, timeZoneIdentifier: String) -> URL {
        withTimeZone(feedsURL.appendingPathComponent(feedID), timeZoneIdentifier: timeZoneIdentifier)
    }

    // Views, memberships, and events use the published-view API; legacy views stay unread.
    static var viewsURL: URL { baseURL.appendingPathComponent("v2/views") }

    static func viewURL(_ id: String) -> URL { viewsURL.appendingPathComponent(id) }

    static func deviceViewsURL(deviceRow: Int) -> URL {
        baseURL.appendingPathComponent("v2/devices/\(deviceRow)/views")
    }

    /// `selector` is the one effective selector, or empty for all joined views.
    static func deviceEventsURL(deviceRow: Int, selector: [URLQueryItem],
                                timeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier) -> URL {
        withTimeZone(baseURL.appendingPathComponent("v2/devices/\(deviceRow)/events"),
                     selector: selector, timeZoneIdentifier: timeZoneIdentifier)
    }

    static func publicEventsURL(viewIDs: [String],
                                timeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier) -> URL {
        withTimeZone(baseURL.appendingPathComponent("v2/events"),
                     selector: [URLQueryItem(name: "viewIds", value: viewIDs.joined(separator: ","))],
                     timeZoneIdentifier: timeZoneIdentifier)
    }

    private static func withTimeZone(_ url: URL, selector: [URLQueryItem] = [], timeZoneIdentifier: String) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = selector + [URLQueryItem(name: "timeZone", value: timeZoneIdentifier)]
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url!
    }

}
