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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: Provider.Entry
    let presentation: WidgetPresentation

    private var visibleItems: [WidgetItem] {
        family == .systemLarge
            ? Array(entry.payload.items.prefix(2))
            : Array(entry.payload.items.prefix(1))
    }

    private var focusedItemID: String? {
        guard family == .systemLarge, let defaultItemID = visibleItems.first?.id else {
            return nil
        }
        return visibleItems.contains(where: { $0.id == entry.focusedItemID })
            ? entry.focusedItemID
            : defaultItemID
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

    private var actionForegroundColor: Color {
        Color(srgb: presentation.fullColor.primarySurface)
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

                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: 24) {
                        if family == .systemLarge {
                            ForEach(visibleItems) { item in
                                SystemFocusableItemView(
                                    item: item,
                                    isPrimary: item.id == focusedItemID,
                                    reduceMotion: reduceMotion,
                                    contentColor: contentColor,
                                    timeAccentColor: timeAccentColor,
                                    actionForegroundColor: actionForegroundColor
                                )
                            }
                        } else if let primary = visibleItems.first {
                            SystemItemBlockView(
                                item: primary,
                                contentColor: contentColor,
                                timeAccentColor: timeAccentColor
                            )
                        }
                    }
                    .foregroundStyle(contentColor)
                    .padding(padding)
                    .animation(
                        reduceMotion ? nil : .smooth(duration: 0.35),
                        value: focusedItemID
                    )

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
    let item: WidgetItem
    let contentColor: Color
    let timeAccentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SystemDateTimeView(item: item, accentColor: timeAccentColor, style: .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.mainText)
                .font(.system(.title, design: .default))
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

private struct SystemFocusableItemView: View {
    let item: WidgetItem
    let isPrimary: Bool
    let reduceMotion: Bool
    let contentColor: Color
    let timeAccentColor: Color
    let actionForegroundColor: Color

    var body: some View {
        SystemFocusItemLayout(primaryProgress: isPrimary ? 1 : 0) {
            VStack(alignment: .leading, spacing: isPrimary ? 10 : 4) {
                SystemDateTimeView(
                    item: item,
                    accentColor: timeAccentColor,
                    style: isPrimary ? .primary : .secondary
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.interpolate)

                Text(item.mainText)
                    .font(.system(
                        isPrimary ? .largeTitle : .body,
                        design: .default,
                        weight: isPrimary ? .regular : .semibold
                    ))
                    .lineLimit(isPrimary ? 2 : 1)
                    .multilineTextAlignment(.leading)
                    .truncationMode(.tail)
                    .foregroundStyle(contentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.interpolate)
            }

            SystemRoleDetailLayout(primaryProgress: isPrimary ? 1 : 0) {
                Text(item.subText)
                    .font(.system(.title3, design: .default, weight: .regular))
                    .foregroundStyle(contentColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(isPrimary ? 1 : 0)

                Button(intent: FocusWidgetItemIntent(itemID: item.id)) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(actionForegroundColor)
                        .frame(width: 56, height: 56)
                        .background(timeAccentColor, in: Circle())
                        .contentShape(Rectangle())
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .buttonStyle(SystemFocusButtonStyle(reduceMotion: reduceMotion))
                .allowsHitTesting(!isPrimary)
                .accessibilityLabel("Show \(item.mainText) larger")
                .accessibilityHidden(isPrimary)
                .opacity(isPrimary ? 0 : 1)
            }
            .clipped()
        }
        .padding(isPrimary ? 20 : 14)
        .frame(
            maxWidth: .infinity,
            maxHeight: isPrimary ? .infinity : nil,
            alignment: .topLeading
        )
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isPrimary ? contentColor.opacity(0.08) : .clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    contentColor.opacity(0.45),
                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                )
                .opacity(isPrimary ? 0 : 1)
        }
        .id(item.id)
    }
}

private struct SystemFocusButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
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
