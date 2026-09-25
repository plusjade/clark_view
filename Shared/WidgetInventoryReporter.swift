import Foundation
import OSLog
import WidgetKit

/// Uploads the device's current widget configurations when they change, when none has
/// succeeded, or daily. Runs from widget timelines, app activation, and pairing; never polls
/// or reloads timelines. Callers await it, so the extension never depends on an orphaned task.
actor WidgetInventoryReporter {
    static let shared = WidgetInventoryReporter()

    enum Trigger {
        case timeline, appActivation, pairing
    }

    private static let deadline: Duration = .seconds(3)
    private static let stateKey = "widgetInventoryReportState"
    private static let logger = Logger(subsystem: "plusjade.clark-view", category: "WidgetInventory")

    private var inFlight: Task<Void, Never>?

    /// Overlapping calls share one run. Pairing follows any run in progress with its own,
    /// because a pre-pairing attempt was rejected and must not hold the retry cooldown.
    func report(trigger: Trigger) async {
        if let inFlight {
            await inFlight.value
            guard trigger == .pairing else { return }
        }
        let task = Task { await Self.runWithDeadline(ignoringCooldown: trigger == .pairing) }
        inFlight = task
        await task.value
        if inFlight == task { inFlight = nil }
    }

    private static func runWithDeadline(ignoringCooldown: Bool) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await perform(ignoringCooldown: ignoringCooldown) }
            group.addTask { try? await Task.sleep(for: deadline) }
            await group.next()
            group.cancelAll()
        }
    }

    private static func perform(ignoringCooldown: Bool) async {
        let infos: [WidgetInfo]
        do {
            infos = try await WidgetCenter.shared.currentConfigurations()
        } catch {
            // A failed query is not an empty inventory; never upload it as one.
            logger.error("Widget configurations unavailable: \(error.localizedDescription, privacy: .public)")
            return
        }
        let entries = infos.map {
            WidgetInventoryEntry(kind: $0.kind, family: $0.family.inventoryName,
                                 intent: $0.widgetConfigurationIntent(of: WidgetFeedIntent.self))
        }
        let signature = WidgetInventoryPolicy.signature(of: entries)
        var state = loadState()
        let now = Date.now
        guard WidgetInventoryPolicy.shouldUpload(signature: signature, state: state, now: now,
                                                 ignoringCooldown: ignoringCooldown) else { return }
        if await upload(entries, observedAt: now) {
            state = WidgetInventoryReportState(lastUploadedSignature: signature, lastSuccessAt: now)
        } else {
            state.lastFailureAt = now
        }
        saveState(state)
    }

    private struct Upload: Encodable {
        let device: String
        let observedAt: String
        let widgets: [WidgetInventoryEntry]
    }

    private static func upload(_ entries: [WidgetInventoryEntry], observedAt: Date) async -> Bool {
        var request = URLRequest(url: ServerURL.baseURL.appendingPathComponent("device/widget-inventory"))
        request.httpMethod = "POST"
        request.timeoutInterval = 3
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        request.httpBody = try? JSONEncoder().encode(Upload(
            device: DeviceIdentity.deviceID, observedAt: formatter.string(from: observedAt), widgets: entries
        ))
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if !(200..<300).contains(status) { logger.notice("Inventory upload rejected: HTTP \(status)") }
            return (200..<300).contains(status)
        } catch {
            logger.notice("Inventory upload failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: DeviceIdentity.appGroupID) ?? .standard
    }

    private static func loadState() -> WidgetInventoryReportState {
        guard let data = defaults.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(WidgetInventoryReportState.self, from: data) else {
            return WidgetInventoryReportState()
        }
        return state
    }

    private static func saveState(_ state: WidgetInventoryReportState) {
        defaults.set(try? JSONEncoder().encode(state), forKey: stateKey)
    }
}
