//
//  ContentView.swift
//  clark_view
//
//  Created by Jade Dominguez on 8/18/26.
//

import SwiftUI

/// The receiver has exactly one job: get paired, then get out of the way. Teams and
/// sports are configured from a browser, not this app — see docs/widget-config-plan.md.
struct ContentView: View {
    @State private var isPaired = DeviceIdentity.isPaired

    var body: some View {
        if isPaired {
            PairedView()
        } else {
            PairingView(onPaired: { isPaired = true })
        }
    }
}

private struct PairedView: View {
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
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
