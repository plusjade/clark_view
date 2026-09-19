import ActivityKit
import Foundation

/// A standalone presentation session coordinated by its own server record.
nonisolated struct ClarkLiveActivityAttributes: ActivityAttributes {
    let recordID: String

    struct ContentState: Codable, Hashable {
        var title: String
        var message: String
        var status: String
        var progress: Double?

        static let sample = ContentState(
            title: "An evening out", message: "Getting everything ready", status: "Preparing", progress: 0.25
        )

        var isValid: Bool {
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.utf16.count <= 80
                && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && message.utf16.count <= 240
                && !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && status.utf16.count <= 24
                && (progress.map { $0.isFinite && (0...1).contains($0) } ?? true)
        }

        // Keep null explicit: the server distinguishes no progress from an invalid omitted field.
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(title, forKey: .title)
            try container.encode(message, forKey: .message)
            try container.encode(status, forKey: .status)
            try container.encode(progress, forKey: .progress)
        }
    }
}
