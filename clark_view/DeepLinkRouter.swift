import Foundation
import SwiftUI

/// Converts system handoffs into app navigation without changing the ordinary launch path.
@Observable
final class DeepLinkRouter {
    var destination: AppDeepLink?

    func open(_ url: URL) {
        destination = AppDeepLink(url: url)
    }

    func openNotification(deepLink rawURL: String?, title: String?, body: String?) {
        if let rawURL,
           let url = URL(string: rawURL),
           let destination = AppDeepLink(url: url) {
            self.destination = destination
            return
        }

        guard let title else { return }
        destination = AppDeepLink(
            kind: .notification,
            subjectID: UUID().uuidString,
            title: title,
            detail: body
        )
    }
}

struct DeepLinkDetailView: View {
    let destination: AppDeepLink

    var body: some View {
        List {
            Section {
                Label(destination.status ?? destination.kind.title, systemImage: destination.kind.systemImage)
                    .foregroundStyle(.secondary)

                Text(destination.title)
                    .font(.title2.weight(.semibold))

                if let detail = destination.detail {
                    Text(detail)
                }
            }

            if let startsAt = destination.startsAt {
                Section("Timing") {
                    LabeledContent("Starts") {
                        Text(startsAt, format: .dateTime.weekday(.wide).month(.wide).day().hour().minute())
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            if let progress = destination.progress {
                Section("Progress") {
                    ProgressView(value: progress) {
                        Text(destination.status ?? "Progress")
                    } currentValueLabel: {
                        Text(progress, format: .percent.precision(.fractionLength(0)))
                    }
                }
            }
        }
        .navigationTitle(destination.kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
