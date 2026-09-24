import SwiftUI

/// The paired app reads the same composed feed as the widget and presents every item.
struct FeedHomeView: View {
    @Environment(DeepLinkRouter.self) private var deepLinks
    @Environment(\.scenePhase) private var scenePhase
    @State private var payload: WidgetPayload?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let payload {
                    if payload.items.isEmpty {
                        ContentUnavailableView("Nothing here right now 🫨", systemImage: "sportscourt")
                            .frame(maxWidth: .infinity)
                    } else {
                        TimelineView(.periodic(from: .now, by: 30)) { timeline in
                            VStack(spacing: 16) {
                                ForEach(Array(payload.items.enumerated()), id: \.element.id) { index, item in
                                    Button {
                                        deepLinks.destination = AppDeepLink(
                                            kind: .event,
                                            subjectID: item.id,
                                            title: item.mainText,
                                            detail: item.subText,
                                            startsAt: item.startsAt
                                        )
                                    } label: {
                                        FeedItemCard(item: item, isPrimary: index == 0)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .environment(\.widgetLifecycle, WidgetLifecycleContext(
                                labels: payload.lifecycle,
                                now: timeline.date
                            ))
                        }
                    }
                } else if isLoading {
                    ProgressView("Loading feed")
                        .frame(maxWidth: .infinity)
                } else {
                    ContentUnavailableView("Feed unavailable", systemImage: "wifi.exclamationmark")
                        .frame(maxWidth: .infinity)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Try Again") { Task { await load() } }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("feedHome")
        .refreshable { await load() }
        .task { await load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await load() } }
        }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let timeZone = TimeZone.autoupdatingCurrent
        // The resolver ignores legacy dimensions; both app and widget read this same route.
        let url = ServerURL.resolveURL(
            device: DeviceIdentity.deviceID,
            pixelWidth: 0,
            pixelHeight: 0,
            tzSecondsFromGMT: timeZone.secondsFromGMT(),
            timeZoneIdentifier: timeZone.identifier
        )
        do {
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                throw FeedError.invalidResponse
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            payload = try decoder.decode(WidgetPayload.self, from: data)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t refresh the feed. Pull down to retry."
        }
    }
}

private enum FeedError: Error {
    case invalidResponse
}

/// Uses the large widget's date line, type scale, surface, and focused-first hierarchy.
private struct FeedItemCard: View {
    let item: WidgetItem
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isPrimary ? 10 : 8) {
            BeaconDateTimeView(item: item, style: isPrimary ? .primary : .secondary)

            Text(item.mainText)
                .font(.system(isPrimary ? .largeTitle : .title3, weight: isPrimary ? .regular : .semibold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.subText)
                .font(.system(isPrimary ? .title3 : .subheadline))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.primary)
        .padding(isPrimary ? 20 : 14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(uiColor: .separator), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}
