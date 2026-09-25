import Combine
import SwiftUI
import WidgetKit

/// Widget push registration and the App Group refresh audit trail. The widget writes the
/// trail from its own process, so the panel polls instead of observing.
struct WidgetDiagnosticsView: View {
    @State private var refresh = WidgetRefreshDiagnostics.snapshot
    private let ticks = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section("Refresh") {
                DiagnosticRow("Widget Push", PushTokenClient.registrationStatus)
                DiagnosticRow("Requested", date: refresh.lastRequestedAt)
                DiagnosticRow("Last Attempt", date: refresh.lastAttemptedAt)
                DiagnosticRow("Last Success", date: refresh.lastSucceededAt)
                DiagnosticRow("Last Result", refresh.resultDescription)
            }

            Section {
                Button("Request Widget Refresh", systemImage: "arrow.clockwise") {
                    WidgetRefreshDiagnostics.recordManualRequest()
                    WidgetFocusStore.requireNetworkRefresh()
                    WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.configurable)
                    refresh = WidgetRefreshDiagnostics.snapshot
                }
            } footer: {
                Text("A requested reload is scheduled by the system; the widget records the attempt when it runs.")
            }
        }
        .navigationTitle("Widget")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(ticks) { _ in refresh = WidgetRefreshDiagnostics.snapshot }
    }
}
