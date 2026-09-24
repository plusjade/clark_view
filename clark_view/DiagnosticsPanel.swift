import SwiftUI

/// The menu holds notification setup and device diagnostics beside the live feed.
enum DiagnosticsPanel: String, Identifiable {
    case device
    case notifications
    case widget
    case liveActivity

    var id: String { rawValue }

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

/// Toolbar launcher: device and delivery status first, then the surfaces they feed.
struct DiagnosticsMenu: View {
    @Binding var selection: DiagnosticsPanel?

    var body: some View {
        Menu("Menu", systemImage: "ellipsis") {
            Section {
                item(.device)
                item(.notifications)
            }
            Section("Surfaces") {
                item(.widget)
                item(.liveActivity)
            }
        }
    }

    private func item(_ panel: DiagnosticsPanel) -> some View {
        Button(panel.title, systemImage: panel.systemImage) { selection = panel }
    }
}

extension View {
    /// Presents a panel as a dismissible sheet, giving each one its own navigation context.
    func diagnosticsPanel(_ selection: Binding<DiagnosticsPanel?>) -> some View {
        sheet(item: selection) { panel in
            NavigationStack {
                panel.destination
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { selection.wrappedValue = nil }
                        }
                    }
            }
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
