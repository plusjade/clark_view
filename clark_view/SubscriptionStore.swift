import Foundation

/// Feeds joined in builds that predate lists, shown read-only on the compatibility screens.
@MainActor @Observable
final class SubscriptionStore {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private(set) var phase = Phase.loading
    private(set) var subscriptions: [Subscription] = []

    func load() async {
        guard let id = await AppDevice.resolve() else {
            phase = .failed(SubscriptionClientError.invalidResponse.localizedDescription)
            return
        }
        do {
            let index = try await SubscriptionClient.index(deviceID: id)
            subscriptions = index.subscriptions
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func subscription(id: Int) -> Subscription? {
        subscriptions.first { $0.id == id }
    }
}
