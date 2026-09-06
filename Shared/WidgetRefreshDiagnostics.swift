//
//  WidgetRefreshDiagnostics.swift
//  Shared
//

import Foundation

/// Small App Group-backed audit trail for the beta diagnostics screen. The widget writes
/// network outcomes; the containing app reads them without participating in the data path.
struct WidgetRefreshDiagnosticSnapshot {
    let lastRequestedAt: Date?
    let lastAttemptedAt: Date?
    let lastSucceededAt: Date?
    let lastFailedAt: Date?
    let lastError: String?

    var resultDescription: String {
        guard let lastAttemptedAt else { return "Not attempted" }
        let lastResultAt = max(lastSucceededAt ?? .distantPast, lastFailedAt ?? .distantPast)
        if lastAttemptedAt > lastResultAt {
            return "In progress"
        }
        if let lastFailedAt, lastFailedAt >= (lastSucceededAt ?? .distantPast) {
            return lastError.map { "Failed: \($0)" } ?? "Failed"
        }
        return "Succeeded"
    }
}

enum WidgetRefreshDiagnostics {
    private enum Key {
        static let requestedAt = "widgetRefreshRequestedAt"
        static let attemptedAt = "widgetRefreshAttemptedAt"
        static let succeededAt = "widgetRefreshSucceededAt"
        static let failedAt = "widgetRefreshFailedAt"
        static let error = "widgetRefreshError"
    }

    private static let defaults = UserDefaults(suiteName: DeviceIdentity.appGroupID) ?? .standard

    static var snapshot: WidgetRefreshDiagnosticSnapshot {
        WidgetRefreshDiagnosticSnapshot(
            lastRequestedAt: defaults.object(forKey: Key.requestedAt) as? Date,
            lastAttemptedAt: defaults.object(forKey: Key.attemptedAt) as? Date,
            lastSucceededAt: defaults.object(forKey: Key.succeededAt) as? Date,
            lastFailedAt: defaults.object(forKey: Key.failedAt) as? Date,
            lastError: defaults.string(forKey: Key.error)
        )
    }

    static func recordManualRequest(at date: Date = .now) {
        defaults.set(date, forKey: Key.requestedAt)
    }

    static func recordAttempt(at date: Date = .now) {
        defaults.set(date, forKey: Key.attemptedAt)
    }

    static func recordSuccess(at date: Date = .now) {
        defaults.set(date, forKey: Key.succeededAt)
        defaults.removeObject(forKey: Key.error)
    }

    static func recordFailure(_ message: String, at date: Date = .now) {
        defaults.set(date, forKey: Key.failedAt)
        defaults.set(String(message.prefix(160)), forKey: Key.error)
    }
}
