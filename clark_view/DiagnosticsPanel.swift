import SwiftUI

/// Destinations within the shared diagnostics navigation.
enum DiagnosticsPanel: String, Hashable {
    case device
    case notifications
    case widget
    case liveActivity

    var title: String {
        switch self {
        case .device: "Device"
        case .notifications: "Notifications"
        case .widget: "Widget"
        case .liveActivity: "Live Activity"
        }
    }

    var systemImage: String {
        switch self {
        case .device: "iphone"
        case .notifications: "bell.badge"
        case .widget: "square.grid.2x2"
        case .liveActivity: "bolt.badge.clock"
        }
    }

    @ViewBuilder var destination: some View {
        switch self {
        case .device: DeviceDiagnosticsView()
        case .notifications: NotificationSettingsView()
        case .widget: WidgetDiagnosticsView()
        case .liveActivity: LiveActivityDiagnosticsView()
        }
    }
}

/// A lightweight index keeps each diagnostic panel's work scoped to its destination.
struct DiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var path: [DiagnosticsPanel]

    init(initialPanel: DiagnosticsPanel? = nil) {
        _path = State(initialValue: initialPanel.map { [$0] } ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("This device") {
                    link(.device)
                    link(.notifications)
                }
                Section("Surfaces") {
                    link(.widget)
                    link(.liveActivity)
                }
            }
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: DiagnosticsPanel.self) { panel in
                panel.destination
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func link(_ panel: DiagnosticsPanel) -> some View {
        NavigationLink(value: panel) {
            Label(panel.title, systemImage: panel.systemImage)
        }
    }
}

/// Shared read-only presentation for the panels' status rows.
struct DiagnosticRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    init(_ label: String, date: Date?) {
        self.init(label, date?.formatted(date: .abbreviated, time: .standard) ?? "—")
    }

    var body: some View {
        LabeledContent(label) {
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}
