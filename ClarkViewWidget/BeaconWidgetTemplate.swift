//
//  BeaconWidgetTemplate.swift
//  ClarkViewWidget
//

import AppIntents
import SwiftUI
import WidgetKit

/// The standard template's composition expressed without measured scaling. Semantic text
/// styles stay at their system-resolved sizes while the established visual hierarchy remains.
struct BeaconWidgetTemplate: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                BeaconMissingItemsView(message: "Nothing here right now 🫨")
                    .padding(12)
                    .background {
                        BeaconWidgetCardSurface(
                            isFocused: true,
                            usesTranslucency: usesTranslucentSurfaces
                        )
                    }
                    .padding(6)
            } else if family == .systemSmall, let item = entry.payload.items.first {
                BeaconHeroCard(item: item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
                    .background {
                        BeaconWidgetCardSurface(
                            isFocused: true,
                            usesTranslucency: usesTranslucentSurfaces
                        )
                    }
                    .padding(6)
            } else {
                let padding: CGFloat = family == .systemLarge ? 18 : 12

                VStack(alignment: .leading, spacing: 24) {
                    if family == .systemLarge {
                        ForEach(visibleItems) { item in
                            BeaconFocusableItemView(
                                item: item,
                                isPrimary: item.id == focusedItemID,
                                reduceMotion: reduceMotion,
                                usesTranslucency: usesTranslucentSurfaces
                            )
                        }
                    } else if let primary = visibleItems.first {
                        BeaconItemBlockView(item: primary)
                    }
                }
                .foregroundStyle(.primary)
                .padding(padding)
                .animation(
                    reduceMotion ? nil : .smooth(duration: 0.35),
                    value: focusedItemID
                )
                .background {
                    if family != .systemLarge {
                        BeaconWidgetCardSurface(
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
            Color(srgb: colorScheme == .dark
                ? presentation.rootSurface.dark
                : presentation.rootSurface.light)
        }
    }
}

private struct BeaconHeroCard: View {
    let item: WidgetItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BeaconDateTimeView(item: item, style: .primary)

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
                .font(.system(.title3, design: .default, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BeaconFocusableItemView: View {
    let item: WidgetItem
    let isPrimary: Bool
    let reduceMotion: Bool
    let usesTranslucency: Bool

    var body: some View {
        Button(intent: FocusWidgetItemIntent(itemID: item.id, changesFocus: !isPrimary)) {
            BeaconFocusItemLayout(primaryProgress: isPrimary ? 1 : 0) {
                BeaconDateTimeView(
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
                    .background(BeaconWidgetPalette.actionSurface, in: Circle())
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
                BeaconWidgetCardSurface(
                    isFocused: isPrimary,
                    usesTranslucency: usesTranslucency
                )
            }
            .overlay {
                ZStack {
                    BeaconWidgetPalette.cardShape
                        .strokeBorder(BeaconWidgetPalette.focusedBorder, lineWidth: 1)
                        .opacity(isPrimary ? 1 : 0)

                    BeaconWidgetPalette.cardShape
                        .strokeBorder(
                            BeaconWidgetPalette.compactBorder,
                            style: StrokeStyle(lineWidth: 1, dash: [1, 5])
                        )
                        .opacity(isPrimary ? 0 : 1)
                }
            }
            .contentShape(BeaconWidgetPalette.cardShape)
        }
        .buttonStyle(BeaconFocusButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(
            isPrimary ? "\(item.mainText), focused item" : "Show \(item.mainText) larger"
        )
        .accessibilityHint(isPrimary ? "Already shown larger" : "Shows this item larger")
        .id(item.id)
    }
}

private struct BeaconFocusButtonStyle: ButtonStyle {
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

private struct BeaconDateTimeView: View {
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
    let isFocused: Bool
    let usesTranslucency: Bool

    var body: some View {
        ZStack {
            if usesTranslucency {
                BeaconWidgetPalette.cardShape
                    .fill(.regularMaterial)
                    .opacity(isFocused ? 1 : 0)
            } else {
                BeaconWidgetPalette.cardShape
                    .fill(BeaconWidgetPalette.focusedSurface)
                    .opacity(isFocused ? 1 : 0)
            }
        }
    }
}

private enum BeaconWidgetPalette {
    static let focusedSurface = Color(uiColor: .secondarySystemBackground)
    static let actionSurface = Color(uiColor: .tertiarySystemFill)
    static let focusedBorder = Color(uiColor: .separator)
    static let compactBorder = Color(uiColor: .secondaryLabel)
    static let cardShape = RoundedRectangle(cornerRadius: 12, style: .continuous)
}
