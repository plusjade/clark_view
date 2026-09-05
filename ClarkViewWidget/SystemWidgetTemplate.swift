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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: Provider.Entry

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

    private var usesTranslucentSurfaces: Bool {
        renderingMode == .fullColor && !reduceTransparency
    }

    var body: some View {
        Group {
            if entry.payload.items.isEmpty {
                SystemMissingItemsView(
                    message: "Nothing here right now 🫨",
                    usesTranslucency: usesTranslucentSurfaces
                )
                    .padding(12)
                    .background {
                        SystemWidgetCardSurface(
                            isFocused: true,
                            usesTranslucency: usesTranslucentSurfaces
                        )
                    }
                    .padding(6)
            } else if family == .systemSmall, let item = entry.payload.items.first {
                SystemHeroCard(item: item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
                    .background {
                        SystemWidgetCardSurface(
                            isFocused: true,
                            usesTranslucency: usesTranslucentSurfaces
                        )
                    }
                    .padding(6)
            } else {
                let padding: CGFloat = family == .systemLarge ? 18 : 12

                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: 24) {
                        if family == .systemLarge {
                            ForEach(visibleItems) { item in
                                SystemFocusableItemView(
                                    item: item,
                                    isPrimary: item.id == focusedItemID,
                                    reduceMotion: reduceMotion,
                                    usesTranslucency: usesTranslucentSurfaces
                                )
                            }
                        } else if let primary = visibleItems.first {
                            SystemItemBlockView(item: primary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding(padding)
                    .animation(
                        reduceMotion ? nil : .smooth(duration: 0.35),
                        value: focusedItemID
                    )

                    SystemRefreshButton(usesTranslucency: usesTranslucentSurfaces)
                }
                .background {
                    if family != .systemLarge {
                        SystemWidgetCardSurface(
                            isFocused: true,
                            usesTranslucency: usesTranslucentSurfaces
                        )
                    }
                }
                .padding(family == .systemLarge ? 0 : 6)
            }
        }
        .tint(Color("AccentColor"))
        .containerBackground(for: .widget) {
            colorScheme == .dark ? Color.black : Color.white
        }
    }
}

private struct SystemHeroCard: View {
    let item: WidgetItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SystemDateTimeView(item: item, style: .primary)

            Text(item.mainText)
                .font(.system(.largeTitle, design: .default, weight: .black))
                .lineLimit(1)

            Text(item.subText)
                .font(.system(.subheadline, design: .default, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .foregroundStyle(.primary)
    }
}

private struct SystemItemBlockView: View {
    let item: WidgetItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SystemDateTimeView(item: item, style: .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.mainText)
                .font(.system(.title, design: .default))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.subText)
                .font(.system(.title3, design: .default, weight: .regular))
                .foregroundStyle(.secondary)
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
    let usesTranslucency: Bool

    var body: some View {
        Button(intent: FocusWidgetItemIntent(itemID: item.id, changesFocus: !isPrimary)) {
            SystemFocusItemLayout(primaryProgress: isPrimary ? 1 : 0) {
                SystemDateTimeView(
                    item: item,
                    style: isPrimary ? .primary : .secondary
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.interpolate)

                Text(item.mainText)
                    .font(.system(
                        isPrimary ? .largeTitle : .title3,
                        design: .default,
                        weight: isPrimary ? .regular : .semibold
                    ))
                    .lineLimit(isPrimary ? 2 : 1)
                    .multilineTextAlignment(.leading)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.interpolate)

                Text(item.subText)
                    .font(.system(.title3, design: .default, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(isPrimary ? 1 : 0)

                Image(systemName: "plus.magnifyingglass")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.tint)
                    .frame(width: 50, height: 50)
                    .background(SystemWidgetPalette.actionSurface, in: Circle())
                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .trailing)
                    .opacity(isPrimary ? 0 : 1)
            }
            .padding(isPrimary ? 20 : 14)
            .frame(
                maxWidth: .infinity,
                maxHeight: isPrimary ? .infinity : nil,
                alignment: .topLeading
            )
            .background {
                SystemWidgetCardSurface(
                    isFocused: isPrimary,
                    usesTranslucency: usesTranslucency
                )
            }
            .overlay {
                ZStack {
                    SystemWidgetPalette.cardShape
                        .strokeBorder(SystemWidgetPalette.focusedBorder, lineWidth: 1)
                        .opacity(isPrimary ? 1 : 0)

                    SystemWidgetPalette.cardShape
                        .strokeBorder(
                            SystemWidgetPalette.compactBorder,
                            style: StrokeStyle(lineWidth: 1, dash: [2, 8])
                        )
                        .opacity(isPrimary ? 0 : 1)
                }
            }
            .contentShape(SystemWidgetPalette.cardShape)
        }
        .buttonStyle(SystemFocusButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(
            isPrimary ? "\(item.mainText), focused item" : "Show \(item.mainText) larger"
        )
        .accessibilityHint(isPrimary ? "Already shown larger" : "Shows this item larger")
        .id(item.id)
    }
}

private struct SystemFocusButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
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
            .foregroundStyle(.tint)
            .widgetAccentable()
    }
}

private struct SystemRefreshButton: View {
    let usesTranslucency: Bool

    var body: some View {
        Button(intent: RefreshWidgetIntent()) {
            Label("Refresh", systemImage: "arrow.clockwise")
                .labelStyle(.iconOnly)
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background {
                    if usesTranslucency {
                        Circle()
                            .fill(.regularMaterial)
                    } else {
                        Circle()
                            .fill(SystemWidgetPalette.controlSurface)
                    }
                }
                .overlay {
                    Circle()
                        .strokeBorder(SystemWidgetPalette.focusedBorder, lineWidth: 1)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct SystemMissingItemsView: View {
    let message: String
    let usesTranslucency: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 6) {
                Image(systemName: "sportscourt")
                    .font(.largeTitle)

                Text(message)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            SystemRefreshButton(usesTranslucency: usesTranslucency)
        }
    }
}

private struct SystemWidgetCardSurface: View {
    let isFocused: Bool
    let usesTranslucency: Bool

    var body: some View {
        ZStack {
            if usesTranslucency {
                SystemWidgetPalette.cardShape
                    .fill(.regularMaterial)
                    .opacity(isFocused ? 1 : 0)
            } else {
                SystemWidgetPalette.cardShape
                    .fill(SystemWidgetPalette.focusedSurface)
                    .opacity(isFocused ? 1 : 0)
            }
        }
    }
}

private enum SystemWidgetPalette {
    static let focusedSurface = Color(uiColor: .secondarySystemBackground)
    static let controlSurface = Color(uiColor: .tertiarySystemBackground)
    static let actionSurface = Color(uiColor: .tertiarySystemFill)
    static let focusedBorder = Color(uiColor: .separator)
    static let compactBorder = Color(uiColor: .secondaryLabel)
    static let cardShape = RoundedRectangle(cornerRadius: 12, style: .continuous)
}
