import Foundation

/// One destination contract for every system surface that can hand activity to the app.
struct AppDeepLink: Hashable, Identifiable {
    enum Kind: String {
        case event
        case view
        case liveActivity = "live-activity"
        case notification

        var title: String {
            switch self {
            case .event: "Event"
            case .view: "View"
            case .liveActivity: "Live Activity"
            case .notification: "Notification"
            }
        }

        var systemImage: String {
            switch self {
            case .event: "calendar"
            case .view: "list.bullet.rectangle"
            case .liveActivity: "bolt.badge.clock"
            case .notification: "bell.badge"
            }
        }
    }

    static let scheme = "clarkview"
    /// Views link as `clarkview://v2/view/<published-view-id>`. The legacy numeric
    /// `clarkview://view/<n>` form no longer opens anything.
    static let viewHost = "v2"

    let kind: Kind
    let subjectID: String
    let title: String
    let detail: String?
    let status: String?
    let startsAt: Date?
    let progress: Double?

    var id: String { kind.rawValue + ":" + subjectID }

    var url: URL? {
        var components = URLComponents()
        components.scheme = Self.scheme
        if kind == .view {
            components.host = Self.viewHost
            components.path = "/view/" + subjectID
            return components.url
        }
        components.host = kind.rawValue
        components.path = "/" + subjectID
        components.queryItems = [
            URLQueryItem(name: "title", value: title),
            detail.map { URLQueryItem(name: "detail", value: $0) },
            status.map { URLQueryItem(name: "status", value: $0) },
            startsAt.map { URLQueryItem(name: "startsAt", value: String($0.timeIntervalSince1970)) },
            progress.map { URLQueryItem(name: "progress", value: String($0)) }
        ].compactMap { $0 }
        return components.url
    }

    init(
        kind: Kind,
        subjectID: String,
        title: String,
        detail: String? = nil,
        status: String? = nil,
        startsAt: Date? = nil,
        progress: Double? = nil
    ) {
        self.kind = kind
        self.subjectID = subjectID
        self.title = title
        self.detail = detail
        self.status = status
        self.startsAt = startsAt
        self.progress = progress
    }

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == Self.scheme,
              let host = components.host else { return nil }
        if host == Self.viewHost {
            let prefix = "/view/"
            let subjectID = String(components.path.dropFirst(prefix.count))
            guard components.path.hasPrefix(prefix), PublishedViewID.isValid(subjectID),
                  components.queryItems?.isEmpty ?? true else { return nil }
            self.init(kind: .view, subjectID: subjectID, title: "")
            return
        }
        guard let kind = Kind(rawValue: host), kind != .view, !components.path.isEmpty else { return nil }

        let values = Dictionary(
            components.queryItems?.compactMap { item in
                item.value.map { (item.name, $0) }
            } ?? [],
            uniquingKeysWith: { first, _ in first }
        )
        let subjectID = String(components.path.dropFirst())
        guard let title = values["title"], !title.isEmpty else { return nil }

        self.init(
            kind: kind,
            subjectID: subjectID,
            title: title,
            detail: values["detail"],
            status: values["status"],
            startsAt: values["startsAt"].flatMap(TimeInterval.init).map {
                Date(timeIntervalSince1970: $0)
            },
            progress: values["progress"].flatMap(Double.init)
        )
    }
}
