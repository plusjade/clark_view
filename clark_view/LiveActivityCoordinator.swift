import ActivityKit
import SwiftUI

/// Owns the spike's one local session and observes ActivityKit even when diagnostics is closed.
@MainActor
@Observable
final class LiveActivityCoordinator {
    var record: LiveActivityClient.Record?
    var localState = "Not started"
    var errorMessage: String?
    var isWorking = false
    var activitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    private var session: LiveActivityClient.Session?
    private var activity: Activity<ClarkLiveActivityAttributes>?
    private var observationTasks: [Task<Void, Never>] = []
    private let storageKey = "liveActivitySpikeSession"
    private let startedKey = "liveActivitySpikeStarted"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            session = try? JSONDecoder().decode(LiveActivityClient.Session.self, from: data)
        }
    }

    var hasSession: Bool { session != nil }
    var canStart: Bool {
        activitiesEnabled && !isWorking && (session == nil || localState == "dismissed"
            || localState == "ended" || localState == "failed" || localState == "Not started")
    }
    var canSend: Bool {
        !isWorking && record?.tokenRegistered == true && record?.desiredState == "active"
            && (localState == "active" || localState == "stale")
    }

    func refresh() async {
        activitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        guard let session else { return }
        if let existing = Activity<ClarkLiveActivityAttributes>.activities.first(where: {
            $0.attributes.recordID == session.id
        }) {
            if activity?.id != existing.id { observe(existing, session: session) }
            if let token = existing.pushToken { await register(token, for: existing, session: session) }
            await report(existing.activityState, session: session)
        } else if UserDefaults.standard.bool(forKey: startedKey) {
            localState = "dismissed"
            await report(.dismissed, session: session)
        }
        do {
            let latest = try await LiveActivityClient.request("status", session: session)
            accept(latest)
            if activity == nil && ["failed", "ended", "dismissed"].contains(latest.deviceState) {
                localState = latest.deviceState
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func start(content: ClarkLiveActivityAttributes.ContentState) async -> Bool {
        guard canStart, content.isValid else { return false }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        if session == nil || ["dismissed", "ended", "failed"].contains(localState) {
            observationTasks.forEach { $0.cancel() }
            observationTasks.removeAll()
            activity = nil
            record = nil
            localState = "Not started"
            session = LiveActivityClient.Session(id: UUID().uuidString, key: UUID().uuidString)
            UserDefaults.standard.set(try? JSONEncoder().encode(session), forKey: storageKey)
            UserDefaults.standard.set(false, forKey: startedKey)
        }
        guard let session else { return false }
        do {
            guard let environment = PushEnvironment.current else {
                throw LiveActivityClient.Failure(message: "Couldn’t determine the signed APNs environment.")
            }
            let created = try await LiveActivityClient.request("create", session: session,
                body: .init(environment: environment, content: content))
            accept(created)
            guard created.desiredState == "active", created.deviceState == "prepared" else {
                throw LiveActivityClient.Failure(message: "This record has already been started or finished.")
            }
            do {
                let started = try Activity.request(
                    attributes: ClarkLiveActivityAttributes(recordID: session.id),
                    content: ActivityContent(state: created.content, staleDate: nil), pushType: .token
                )
                UserDefaults.standard.set(true, forKey: startedKey)
                observe(started, session: session)
                await report(started.activityState, session: session)
                return true
            } catch {
                localState = "failed"
                _ = try? await LiveActivityClient.request("observe", session: session, body: .init(state: "failed"))
                throw error
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func send(content: ClarkLiveActivityAttributes.ContentState, end: Bool, alert: Bool = false) async {
        guard canSend, content.isValid, let session, let record else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            accept(try await LiveActivityClient.request(end ? "end" : "update", session: session,
                body: .init(content: content, revision: record.revision, alert: alert)))
        } catch {
            errorMessage = error.localizedDescription
            if let latest = try? await LiveActivityClient.request("status", session: session) { accept(latest) }
        }
    }

    func retryDelivery() async {
        guard !isWorking, let session else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        await refresh()
        do {
            accept(try await LiveActivityClient.request("deliver", session: session, body: .init()))
        } catch { errorMessage = error.localizedDescription }
    }

    func endLocally() async {
        guard !isWorking, let activity, let session else { return }
        isWorking = true
        defer { isWorking = false }
        await activity.end(nil, dismissalPolicy: .immediate)
        await report(.dismissed, session: session)
    }

    private func accept(_ value: LiveActivityClient.Record) {
        guard value.id == session?.id, value.revision >= (record?.revision ?? -1) else { return }
        record = value
    }

    private func observe(_ value: Activity<ClarkLiveActivityAttributes>, session: LiveActivityClient.Session) {
        observationTasks.forEach { $0.cancel() }
        activity = value
        UserDefaults.standard.set(true, forKey: startedKey)
        localState = String(describing: value.activityState)
        observationTasks = [
            Task { [weak self] in
                for await token in value.pushTokenUpdates {
                    guard !Task.isCancelled else { break }
                    await self?.register(token, for: value, session: session)
                }
            },
            Task { [weak self] in
                for await state in value.activityStateUpdates {
                    guard !Task.isCancelled else { break }
                    await self?.report(state, session: session)
                }
            }
        ]
        if let token = value.pushToken {
            observationTasks.append(Task { [weak self] in
                await self?.register(token, for: value, session: session)
            })
        }
    }

    private func register(_ token: Data, for activity: Activity<ClarkLiveActivityAttributes>,
                          session: LiveActivityClient.Session) async {
        do {
            accept(try await LiveActivityClient.request("register", session: session,
                body: .init(activityId: activity.id, token: token.map { String(format: "%02x", $0) }.joined())))
        } catch { errorMessage = "Token sync failed: " + error.localizedDescription }
    }

    private func report(_ state: ActivityState, session: LiveActivityClient.Session) async {
        guard session.id == self.session?.id else { return }
        localState = String(describing: state)
        do {
            accept(try await LiveActivityClient.request("observe", session: session, body: .init(state: localState)))
        } catch { errorMessage = "State sync failed: " + error.localizedDescription }
    }
}
