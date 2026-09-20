import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity surfaces consume ActivityKit snapshots independently of the widget feed.
struct ClarkLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClarkLiveActivityAttributes.self) { context in
            LiveActivityContentView(content: context.state, isStale: context.isStale)
                .padding()
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(.primary)
                .widgetURL(destinationURL(for: context))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "waveform.path")
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.status).font(.caption.weight(.semibold)).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LiveActivityContentView(content: context.state, isStale: context.isStale, showsStatus: false)
                }
            } compactLeading: {
                Image(systemName: "waveform.path")
                    .accessibilityLabel(context.state.title)
            } compactTrailing: {
                if let progress = context.state.progress {
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospacedDigit())
                } else {
                    Text(context.state.status).font(.caption2).lineLimit(1)
                }
            } minimal: {
                Image(systemName: "waveform.path")
                    .accessibilityLabel(context.state.title + ", " + context.state.status)
            }
            .widgetURL(destinationURL(for: context))
        }
    }

    private func destinationURL(
        for context: ActivityViewContext<ClarkLiveActivityAttributes>
    ) -> URL? {
        AppDeepLink(
            kind: .liveActivity,
            subjectID: context.attributes.recordID,
            title: context.state.title,
            detail: context.state.message,
            status: context.state.status,
            progress: context.state.progress
        ).url
    }
}

private struct LiveActivityContentView: View {
    let content: ClarkLiveActivityAttributes.ContentState
    let isStale: Bool
    var showsStatus = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsStatus {
                Text(isStale ? "Waiting for an update" : content.status)
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            Text(content.title).font(.headline).lineLimit(2)
            Text(content.message).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            if let progress = content.progress {
                ProgressView(value: progress)
                    .accessibilityLabel("Progress")
                    .accessibilityValue(progress.formatted(.percent.precision(.fractionLength(0))))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Live Activity", as: .content, using: ClarkLiveActivityAttributes(recordID: "preview")) {
    ClarkLiveActivity()
} contentStates: {
    ClarkLiveActivityAttributes.ContentState.sample
    ClarkLiveActivityAttributes.ContentState(
        title: "A longer title that needs room", message: "The latest message can change independently of time.",
        status: "On the way", progress: nil
    )
}
