//
//  PairingView.swift
//  clark_view
//
//  Created by Jade Dominguez on 8/28/26.
//

import SwiftUI
import WidgetKit

/// Pairs the device before handing off to notification setup.
struct PairingView: View {
    var onPaired: () -> Void

    @State private var code = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "link")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text("Enter Pairing Code")
                        .font(.title2.bold())
                    Text("Get the code from your helper.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                TextField("ABC123", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .font(.system(.title, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Pairing code")
                    .onSubmit(submit)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button(action: submit) {
                    HStack {
                        if isSubmitting { ProgressView() }
                        Text("Pair")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(code.isEmpty || isSubmitting)
            }
            .frame(maxWidth: 420)
            .padding(24)
            .padding(.top, 40)
            .frame(maxWidth: .infinity)
        }
    }

    private func submit() {
        guard !code.isEmpty, !isSubmitting else { return }
        errorMessage = nil
        isSubmitting = true
        Task {
            var outcome = await PairingClient.pair(code: code, device: DeviceIdentity.deviceID)
            if outcome != .paired, outcome != .invalidOrExpiredCode,
               let status = await DeviceStatusClient.fetch(device: DeviceIdentity.deviceID), status.paired {
                outcome = .paired
            }
            isSubmitting = false
            switch outcome {
            case .paired:
                DeviceIdentity.isPaired = true
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.main)
                onPaired()
            case .invalidOrExpiredCode:
                errorMessage = "That code didn't work — ask for a new one."
            case .serverError(let statusCode):
                errorMessage = "The server returned an error (HTTP \(statusCode)). Try again."
            case .invalidResponse:
                errorMessage = "The server sent an unexpected pairing response. Try again."
            case .networkError:
                errorMessage = "Couldn't reach the server. Check your connection and try again."
            }
        }
    }
}

#Preview {
    PairingView(onPaired: {})
}
