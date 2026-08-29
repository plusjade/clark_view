//
//  ContentView.swift
//  clark_view
//
//  Created by Jade Dominguez on 8/18/26.
//

import SwiftUI
import WidgetKit

/// The receiver has exactly one job: get paired, then get out of the way. Teams and
/// sports are configured from a browser, not this app — see docs/widget-config-plan.md.
struct ContentView: View {
    @State private var isPaired = DeviceIdentity.isPaired

    var body: some View {
        if isPaired {
            PairedView(onUnpaired: {
                DeviceIdentity.isPaired = false
                isPaired = false
            })
        } else {
            PairingView(onPaired: { isPaired = true })
        }
    }
}

private struct PairedView: View {
    let onUnpaired: () -> Void

    @State private var status: DeviceStatusClient.DeviceStatus?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("This device is paired")
                .font(.headline)
            Text("Manage teams and favorites from the link set up in the browser.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.main)
            } label: {
                Label("Refresh Widget", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)

            DiagnosticsView(status: status, isLoading: isLoading, onRefresh: refresh)
        }
        .padding()
        .task { await refresh() }
    }

    private func refresh() async {
        isLoading = true
        let fetched = await DeviceStatusClient.fetch(device: DeviceIdentity.deviceID)
        status = fetched
        isLoading = false
        // Only an explicit `paired: false` from the server corrects the local
        // cache — a failed fetch (network blip) comes back nil and must not
        // be treated the same, or a transient error would bounce someone back
        // to the pairing screen.
        if let fetched, !fetched.paired {
            onUnpaired()
        }
    }
}

/// Prototype-level, not user-facing polish: raw fields off `/config/status`,
/// straight from the server, so it's obvious when what's stored doesn't match
/// what's expected — no reformatting that could itself hide a drift.
private struct DiagnosticsView: View {
    let status: DeviceStatusClient.DeviceStatus?
    let isLoading: Bool
    let onRefresh: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Diagnostics")
                    .font(.caption.bold())
                Spacer()
                Button {
                    Task { await onRefresh() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isLoading)
            }

            if let status {
                row("Device ID", status.deviceId)
                row("Device Name", status.name ?? "—")
                row("Config ID", status.configId ?? "—")
                row("Sports", displayList(status.sports))
                row("Teams", displayList(status.teams))
            } else if !isLoading {
                Text("Couldn't load status")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(.footnote, design: .monospaced))
        .padding(10)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func displayList(_ values: [String]?) -> String {
        guard let values, !values.isEmpty else { return "(all)" }
        return values.joined(separator: ", ")
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
        }
    }
}

#Preview {
    ContentView()
}
