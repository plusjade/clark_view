import SwiftUI

/// Editable presentation content makes the spike useful for exploring each Live Activity surface.
struct LiveActivityDiagnosticsView: View {
    @Environment(LiveActivityCoordinator.self) private var coordinator
    @State private var content = ClarkLiveActivityAttributes.ContentState.sample
    @State private var showsProgress = true
    @State private var progress = 0.25

    private var draft: ClarkLiveActivityAttributes.ContentState {
        var value = content
        value.progress = showsProgress ? progress : nil
        return value
    }

    var body: some View {
        Form {
            Section("Content") {
                TextField("Title (80 characters)", text: $content.title)
                TextField("Message (240 characters)", text: $content.message, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Status (24 characters)", text: $content.status)
                Toggle("Show progress", isOn: $showsProgress)
                if showsProgress {
                    Slider(value: $progress, in: 0...1, step: 0.05) { Text("Progress") }
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                }
            }
            Section {
                Button("Create Record and Start") { Task { await coordinator.start(content: draft) } }
                    .disabled(!coordinator.canStart || !draft.isValid)
                Button("Send Update via Server") { Task { await coordinator.send(content: draft, end: false) } }
                    .disabled(!coordinator.canSend || !draft.isValid)
                Button("End via Server", role: .destructive) {
                    Task { await coordinator.send(content: draft, end: true) }
                }
                .disabled(!coordinator.canSend || !draft.isValid)
            } footer: {
                Text("Start creates a standalone server record, then starts locally. "
                     + "Updates and ending arrive through APNs.")
            }
            Section("Diagnostics") {
                LabeledContent("Live Activities",
                               value: coordinator.activitiesEnabled ? "Enabled" : "Disabled in Settings")
                LabeledContent("On this device", value: coordinator.localState)
                if let record = coordinator.record {
                    LabeledContent("Server intent", value: record.desiredState)
                    LabeledContent("Revision", value: String(record.revision))
                    LabeledContent("Push token", value: record.tokenRegistered ? "Registered" : "Waiting")
                    Text(record.deliveryResult).foregroundStyle(.secondary)
                    Button("Load Saved Content") {
                        content = record.content
                        showsProgress = record.content.progress != nil
                        progress = record.content.progress ?? 0
                    }
                }
                if let error = coordinator.errorMessage { Text(error).foregroundStyle(.red) }
                Button("Refresh Status / Retry Token Sync") { Task { await coordinator.refresh() } }
                    .disabled(coordinator.isWorking || !coordinator.hasSession)
                Button("Retry Last Server Delivery") { Task { await coordinator.retryDelivery() } }
                    .disabled(coordinator.isWorking || coordinator.record?.tokenRegistered != true)
                Button("Dismiss Locally", role: .destructive) { Task { await coordinator.endLocally() } }
                    .disabled(coordinator.isWorking || !["active", "stale", "ended"].contains(coordinator.localState))
            }
        }
        .navigationTitle("Live Activity Spike")
        .navigationBarTitleDisplayMode(.inline)
        .task { await coordinator.refresh() }
    }
}
