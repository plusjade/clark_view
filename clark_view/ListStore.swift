import Foundation
import WidgetKit

/// Resolves this installation's device row for the app, creating it on first run.
/// Re-resolved on every load because a browser merge can move the install to another row.
@MainActor
enum AppDevice {
    static func resolve() async -> Int? {
        guard let status = await DeviceStatusClient.fetch(device: DeviceIdentity.deviceID) else { return nil }
        let resolved = status.registered
            ? status.id
            : await DeviceStatusClient.register(device: DeviceIdentity.deviceID)
        guard let id = resolved else { return nil }
        // Widgets read this row without waiting for their own registration round trip.
        DeviceRow.store(id)
        if !status.registered {
            await WidgetInventoryReporter.shared.report(trigger: .registration)
        }
        return id
    }
}

/// The home screen's joined lists, shared by the index, detail, and directory screens.
@MainActor @Observable
final class ListStore {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private(set) var phase = Phase.loading
    private(set) var lists: [JoinedList] = []
    private(set) var delivery: String?
    private(set) var deviceID: Int?

    func load() async {
        guard let id = await AppDevice.resolve() else {
            phase = .failed(SubscriptionClientError.invalidResponse.localizedDescription)
            return
        }
        deviceID = id
        do {
            let memberships = try await ListClient.memberships(deviceID: id)
            lists = memberships.lists
            delivery = memberships.delivery
            // A failed load leaves the last successful picker choices in place.
            WidgetListCatalog.shared.replaceJoined(lists.map(\.list))
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func list(id: String) -> JoinedList? {
        lists.first { $0.id == id }
    }

    func join(_ list: ListSummary) async throws {
        try await ListClient.join(deviceID: try requireDevice(), listID: list.id)
        WidgetListCatalog.shared.recordJoin(list.list)
        await membershipChanged()
    }

    func setReminders(_ list: JoinedList, enabled: Bool) async throws {
        try await ListClient.setReminders(deviceID: try requireDevice(), listID: list.id, enabled: enabled)
        await load()
    }

    func leave(_ list: JoinedList) async throws {
        try await ListClient.leave(deviceID: try requireDevice(), listID: list.id)
        WidgetListCatalog.shared.recordLeave(list.id)
        await membershipChanged()
    }

    /// Widgets resolve membership on the server at fetch time; this only asks WidgetKit
    /// for that fetch sooner. Stored widget selections are never rewritten here.
    private func membershipChanged() async {
        await load()
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.configurable)
    }

    private func requireDevice() throws -> Int {
        guard let deviceID else {
            throw SubscriptionClientError.rejected("Your lists haven’t loaded yet. Try again.")
        }
        return deviceID
    }
}
