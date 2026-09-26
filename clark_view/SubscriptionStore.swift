import Foundation

/// The home screen's subscriptions, shared by the index, show, and form screens.
/// The numeric device ID is re-resolved on each load because a browser merge can move this install to another row.
/// An unregistered install creates its own unpaired device row, so pairing never gates subscriptions.
@MainActor @Observable
final class SubscriptionStore {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private(set) var phase = Phase.loading
    private(set) var subscriptions: [Subscription] = []
    private(set) var delivery: String?
    private(set) var deviceID: Int?

    func load() async {
        guard let status = await DeviceStatusClient.fetch(device: DeviceIdentity.deviceID) else {
            phase = .failed(SubscriptionClientError.invalidResponse.localizedDescription)
            return
        }
        let resolved = status.registered
            ? status.id
            : await DeviceStatusClient.register(device: DeviceIdentity.deviceID)
        guard let id = resolved else {
            phase = .failed(SubscriptionClientError.invalidResponse.localizedDescription)
            return
        }
        deviceID = id
        do {
            let index = try await SubscriptionClient.index(deviceID: id)
            subscriptions = index.subscriptions
            delivery = index.delivery
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func subscription(id: Int) -> Subscription? {
        subscriptions.first { $0.id == id }
    }

    func create(feedID: String, leadSeconds: Int) async throws {
        try await SubscriptionClient.create(deviceID: try requireDevice(), feedID: feedID, leadSeconds: leadSeconds)
        await load()
    }

    func update(_ subscription: Subscription, leadSeconds: Int, enabled: Bool) async throws {
        try await SubscriptionClient.update(deviceID: try requireDevice(), subscriptionID: subscription.id,
                                            leadSeconds: leadSeconds, enabled: enabled)
        await load()
    }

    func delete(_ subscription: Subscription) async throws {
        try await SubscriptionClient.delete(deviceID: try requireDevice(), subscriptionID: subscription.id)
        await load()
    }

    private func requireDevice() throws -> Int {
        guard let deviceID else {
            throw SubscriptionClientError.rejected("Subscriptions haven’t loaded yet. Try again.")
        }
        return deviceID
    }
}
