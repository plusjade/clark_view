import SwiftUI

/// In-app event content between leading status and trailing actions.
/// `id` identifies the list or feed being shown; `fetch` reads its events.
struct FeedPreviewView<Leading: View, Trailing: View>: View {
    let id: String
    let fetch: () async throws -> WidgetPayload
    let leading: Leading
    let trailing: Trailing
    @Environment(DeepLinkRouter.self) private var deepLinks
    @Environment(\.scenePhase) private var scenePhase
    @State private var payload: WidgetPayload?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var requestID = UUID()

    init(id: String, fetch: @escaping () async throws -> WidgetPayload,
         @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.id = id
        self.fetch = fetch
        self.leading = leading()
        self.trailing = trailing()
    }

    init(feed: Feed, @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.init(id: feed.id, fetch: { try await FeedDirectoryClient.payload(for: feed, context: .appPreview) },
                  leading: leading, trailing: trailing)
    }

    init(list: EventList, @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.init(id: "list-\(list.id)", fetch: { try await EventsClient.preview(listID: list.id) },
                  leading: leading, trailing: trailing)
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
                    ProgressView("Loading events")
                        .frame(maxWidth: .infinity)
                } else {
                    ContentUnavailableView("Events unavailable", systemImage: "wifi.exclamationmark")
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
        .onChange(of: id) { _, _ in
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
            let result = try await fetch()
            guard requestID == startedWith else { return }
            payload = result
            errorMessage = nil
        } catch {
            guard requestID == startedWith else { return }
            payload = nil
            errorMessage = (error as? FeedClientError) == .unavailable
                || (error as? EventsClientError) == .feedUnavailable
                ? "This is no longer available."
                : "Couldn’t refresh. Pull down to retry."
        }
    }
}

/// Matches the bell state shown beside each view in My views.
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

/// Uses the large widget's date line, type scale, surface, and primary-first hierarchy.
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
