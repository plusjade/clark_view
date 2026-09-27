import SwiftUI

/// In-app feed content between its reminder controls and supporting actions.
struct FeedPreviewView<Leading: View, Trailing: View>: View {
    let feed: Feed
    let leading: Leading
    let trailing: Trailing
    @Environment(DeepLinkRouter.self) private var deepLinks
    @Environment(\.scenePhase) private var scenePhase
    @State private var payload: WidgetPayload?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var requestID = UUID()

    init(feed: Feed, @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.feed = feed
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 16) {
                leading
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
                        .buttonStyle(.borderless)
                }
                trailing
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("feedPreview")
        .refreshable { await load() }
        .task { await load() }
        .onChange(of: feed.id) { _, _ in
            requestID = UUID()
            payload = nil
            errorMessage = nil
            isLoading = false
            Task { await load() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await load() } }
        }
    }

    private func load() async {
        guard !isLoading else { return }
        let startedWith = requestID
        isLoading = true
        defer { if requestID == startedWith { isLoading = false } }
        do {
            let result = try await FeedDirectoryClient.payload(for: feed, context: .appPreview)
            guard requestID == startedWith else { return }
            payload = result
            errorMessage = nil
        } catch {
            guard requestID == startedWith else { return }
            payload = nil
            errorMessage = error is FeedClientError && (error as? FeedClientError) == .unavailable
                ? "This feed is no longer available."
                : "Couldn’t refresh the feed. Pull down to retry."
        }
    }
}

/// Matches the bell state shown beside each feed in Your feeds.
struct FeedReminderToggle: View {
    @Binding var isOn: Bool
    var isDisabled = false

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "bell.fill" : "bell.slash")
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
                Text("Reminders")
            }
        }
        .disabled(isDisabled)
    }
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
