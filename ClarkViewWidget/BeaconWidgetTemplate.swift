//
//  BeaconWidgetTemplate.swift
//  ClarkViewWidget
//

import SwiftUI
import WidgetKit

struct BeaconWidgetTemplate: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: Provider.Entry
    let presentation: WidgetPresentation

    private var visibleItems: [WidgetItem] {
        family == .systemLarge
            ? Array(entry.payload.items.prefix(2))
            : Array(entry.payload.items.prefix(1))
    }

    private var usesTranslucentSurfaces: Bool {
        renderingMode == .fullColor && !reduceTransparency
    }

    var body: some View {
        Group {
            if entry.payload.items.isEmpty {
                BeaconMissingItemsView(message: "Nothing here right now 🫨")
                    .padding(12)
                    .background {
                        BeaconWidgetCardSurface(
                            usesTranslucency: usesTranslucentSurfaces
                        )
                    }
                    .padding(6)
            } else if family == .systemSmall, let item = entry.payload.items.first {
                BeaconHeroCard(item: item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(10)
            } else if family == .systemLarge {
                BeaconLargeLayout(items: visibleItems)
                    .foregroundStyle(.primary)
            } else if let primary = visibleItems.first {
                BeaconItemBlockView(item: primary)
                    .foregroundStyle(.primary)
                    .padding(16)
            }
        }
        .tint(Color("AccentColor"))
        // The entry's date, not `.now`: a timeline entry is rendered for the moment it was
        // built for, so each item resolves to the label its own window implies then.
        .environment(\.widgetLifecycle, WidgetLifecycleContext(
            labels: entry.payload.lifecycle,
            now: entry.date
        ))
        .containerBackground(for: .widget) {
            Color(srgb: colorScheme == .dark
                ? presentation.rootSurface.dark
                : presentation.rootSurface.light)
        }
    }
}

private struct BeaconHeroCard: View {
    let item: WidgetItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            BeaconDateTimeView(item: item, style: .primary, layout: .stacked)

            Text(item.mainText)
                .font(.system(.title, design: .default, weight: .black))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.primary)
    }
}

private struct BeaconItemBlockView: View {
    let item: WidgetItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BeaconDateTimeView(item: item, style: .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.mainText)
                .font(.system(.title, design: .default))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.subText)
                .font(.system(.title3, design: .monospaced, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BeaconLargeLayout: View {
    let items: [WidgetItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let primary = items.first {
                BeaconLargeItemLink(item: primary)
                    .layoutPriority(1)
            }

            if items.count > 1 {
                Divider()

                BeaconLargeItemLink(item: items[1])
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct BeaconLargeItemLink: View {
    let item: WidgetItem

    @ViewBuilder
    var body: some View {
        if let destinationURL {
            Link(destination: destinationURL) {
                content
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(item.mainText)")
            .accessibilityHint("Opens event details in Clark View")
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            BeaconDateTimeView(item: item, style: .primary)

            Text(item.mainText)
                .font(.system(.largeTitle, design: .default, weight: .regular))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .truncationMode(.tail)

            Text(item.subText)
                .font(.system(.title3, design: .default))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
    }

    private var destinationURL: URL? {
        AppDeepLink(
            kind: .event,
            subjectID: item.id,
            title: item.mainText,
            detail: item.subText,
            startsAt: item.startsAt
        ).url
    }
}

private struct BeaconMissingItemsView: View {
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "sportscourt")
                .font(.largeTitle)

            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BeaconWidgetCardSurface: View {
    let usesTranslucency: Bool

    var body: some View {
        ZStack {
            if usesTranslucency {
                BeaconWidgetPalette.cardShape
                    .fill(.regularMaterial)
            } else {
                BeaconWidgetPalette.cardShape
                    .fill(BeaconWidgetPalette.emptySurface)
            }
        }
    }
}

private enum BeaconWidgetPalette {
    static let emptySurface = Color(uiColor: .secondarySystemBackground)
    static let cardShape = RoundedRectangle(cornerRadius: 12, style: .continuous)
}
