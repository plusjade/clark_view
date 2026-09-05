//
//  SystemWidgetTemplate.swift
//  ClarkViewWidget
//

import AppIntents
import SwiftUI
import WidgetKit

/// The standard template's composition expressed without measured scaling. Semantic text
/// styles stay at their system-resolved sizes while the established visual hierarchy remains.
struct SystemWidgetTemplate: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: Provider.Entry
    let presentation: WidgetPresentation

    private var visibleItems: [WidgetItem] {
        family == .systemLarge
            ? Array(entry.payload.items.prefix(3))
            : Array(entry.payload.items.prefix(1))
    }

    private var contentColor: Color {
        guard renderingMode == .fullColor else { return .primary }
        return presentation.fullColor.primarySurface.contrastingForegroundTone.color
    }

    private var timeAccentColor: Color {
        guard renderingMode == .fullColor else { return contentColor }
        return presentation.fullColor.primarySurface.contrastingForegroundTone == .light
            ? Color(red: 1.0, green: 0.78, blue: 0.0)
            : contentColor
    }

    var body: some View {
        Group {
            if entry.payload.items.isEmpty {
                SystemMissingItemsView(message: "Nothing here right now 🫨", contentColor: contentColor)
            } else if family == .systemSmall, let item = entry.payload.items.first {
                SystemHeroCard(item: item, contentColor: contentColor, timeAccentColor: timeAccentColor)
                    .padding(14)
            } else {
                let padding: CGFloat = 18
                let secondaryItems = visibleItems.dropFirst()

                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: 0) {
                        if let primary = visibleItems.first {
                            SystemItemBlockView(
                                item: primary,
                                contentColor: contentColor,
                                timeAccentColor: timeAccentColor
                            )
                        }

                        Spacer(minLength: secondaryItems.isEmpty ? 0 : 24)

                        if !secondaryItems.isEmpty {
                            VStack(alignment: .trailing, spacing: 14) {
                                Rectangle()
                                    .fill(contentColor.opacity(0.4))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 0.5)

                                VStack(alignment: .trailing, spacing: 12) {
                                    ForEach(Array(secondaryItems), id: \.id) { item in
                                        SystemSecondaryItemRow(
                                            item: item,
                                            contentColor: contentColor,
                                            timeAccentColor: timeAccentColor
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .foregroundStyle(contentColor)
                    .padding(padding)

                    SystemRefreshButton(contentColor: contentColor)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(srgb: presentation.fullColor.primarySurface)
        }
    }
}

private struct SystemHeroCard: View {
    let item: WidgetItem
    let contentColor: Color
    let timeAccentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SystemDateTimeView(item: item, accentColor: timeAccentColor, style: .primary)

            Text(item.mainText)
                .font(.system(.largeTitle, design: .default, weight: .black))
                .lineLimit(1)

            Text(item.subText)
                .font(.system(.subheadline, design: .default, weight: .medium))
                .foregroundStyle(contentColor)
                .lineLimit(2)
        }
        .foregroundStyle(contentColor)
    }
}

private struct SystemItemBlockView: View {
    @Environment(\.widgetFamily) private var family

    let item: WidgetItem
    let contentColor: Color
    let timeAccentColor: Color

    private var titleStyle: Font.TextStyle {
        family == .systemLarge ? .largeTitle : .title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SystemDateTimeView(item: item, accentColor: timeAccentColor, style: .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.mainText)
                .font(.system(titleStyle, design: .default))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.subText)
                .font(.system(.title3, design: .default, weight: .regular))
                .foregroundStyle(contentColor)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SystemSecondaryItemRow: View {
    let item: WidgetItem
    let contentColor: Color
    let timeAccentColor: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            SystemDateTimeView(item: item, accentColor: timeAccentColor, style: .secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(item.mainText)
                .font(.system(.body, design: .default, weight: .semibold))
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
                .truncationMode(.tail)
                .foregroundStyle(contentColor)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct SystemDateTimeView: View {
    enum Style {
        case primary
        case secondary
    }

    let item: WidgetItem
    let accentColor: Color
    let style: Style

    private var label: String {
        let detail = item.caption
            ?? item.timestamp.formatted(date: .omitted, time: .shortened)
        return "\(dayLabel(for: item.timestamp)) · \(detail)"
    }

    private var font: Font {
        switch style {
        case .primary: return .system(.title2, design: .default, weight: .bold)
        case .secondary: return .system(.subheadline, design: .default, weight: .semibold)
        }
    }

    var body: some View {
        Text(label)
            .font(font)
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(accentColor)
            .widgetAccentable()
    }
}

private struct SystemRefreshButton: View {
    let contentColor: Color

    var body: some View {
        Button(intent: RefreshWidgetIntent()) {
            Label("Refresh", systemImage: "arrow.clockwise")
                .labelStyle(.iconOnly)
                .font(.body.weight(.medium))
                .foregroundStyle(contentColor)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SystemMissingItemsView: View {
    let message: String
    let contentColor: Color

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 6) {
                Image(systemName: "sportscourt")
                    .font(.largeTitle)

                Text(message)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(contentColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            SystemRefreshButton(contentColor: contentColor)
        }
    }
}

private extension WidgetForegroundTone {
    var color: Color {
        switch self {
        case .light: return .white
        case .dark: return .black
        }
    }
}
