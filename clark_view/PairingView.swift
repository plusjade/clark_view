//
//  PairingView.swift
//  clark_view
//
//  Created by Jade Dominguez on 8/28/26.
//

import SwiftUI
import WidgetKit

/// The one screen the receiver ever needs: enter the 6-character code shown in
/// whoever-set-up-your-teams's browser (`POST /pair`), then this device is done.
struct PairingView: View {
    var onPaired: () -> Void

    @State private var code = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Enter Pairing Code")
                .font(.title2.bold())
            Text("Ask whoever set up your teams for the 6-character code from their screen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("ABC123", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .multilineTextAlignment(.center)
                .font(.system(.title, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button(action: submit) {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Pair")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(code.isEmpty || isSubmitting)
        }
        .padding()
    }

    private func submit() {
        guard !code.isEmpty else { return }
        errorMessage = nil
        isSubmitting = true
        Task {
            let outcome = await PairingClient.pair(code: code, device: DeviceIdentity.deviceID)
            isSubmitting = false
            switch outcome {
            case .paired:
                DeviceIdentity.isPaired = true
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.main)
                onPaired()
            case .invalidOrExpiredCode:
                errorMessage = "That code didn't work — ask for a new one."
            case .networkError:
                errorMessage = "Couldn't reach the server. Check your connection and try again."
            }
        }
    }
}

#Preview {
    PairingView(onPaired: {})
}
