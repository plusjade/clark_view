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
                    VStack(alignment: .leading, spacing: 0) {
                        if family == .systemLarge {
                            ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                                if index > 0 {
                                    Spacer(minLength: 24)
                                }

                                SystemFocusableItemButton(
                                    item: item,
                                    isPrimary: item.id == focusedItemID,
                                    justification: index == 0 ? .leading : .trailing,
                                    contentColor: contentColor,
                                    timeAccentColor: timeAccentColor
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
                    .animation(.smooth(duration: 0.35), value: focusedItemID)

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

private enum SystemItemJustification {
    case leading
    case trailing

    var alignment: Alignment {
        switch self {
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }

    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }
}

private struct SystemFocusableItemButton: View {
    let item: WidgetItem
    let isPrimary: Bool
    let justification: SystemItemJustification
    let contentColor: Color
    let timeAccentColor: Color

    var body: some View {
        Button(intent: FocusWidgetItemIntent(itemID: item.id)) {
            VStack(alignment: justification.horizontalAlignment, spacing: isPrimary ? 10 : 4) {
                SystemDateTimeView(
                    item: item,
                    accentColor: timeAccentColor,
                    style: isPrimary ? .primary : .secondary
                )
                .frame(maxWidth: .infinity, alignment: justification.alignment)
                .contentTransition(.interpolate)

                Text(item.mainText)
                    .font(.system(
                        isPrimary ? .largeTitle : .body,
                        design: .default,
                        weight: isPrimary ? .regular : .semibold
                    ))
                    .lineLimit(isPrimary ? 2 : 1)
                    .multilineTextAlignment(justification.textAlignment)
                    .truncationMode(.tail)
                    .foregroundStyle(contentColor)
                    .frame(maxWidth: .infinity, alignment: justification.alignment)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.interpolate)

                SystemCollapsibleLayout(progress: isPrimary ? 1 : 0) {
                    Text(item.subText)
                        .font(.system(.title3, design: .default, weight: .regular))
                        .foregroundStyle(contentColor)
                        .lineLimit(2)
                        .multilineTextAlignment(justification.textAlignment)
                        .frame(maxWidth: .infinity, alignment: justification.alignment)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(isPrimary ? 1 : 0)
                }
                .clipped()
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: justification.alignment)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isPrimary
                ? "\(item.mainText), primary item"
                : "Show \(item.mainText) as primary"
        )
        .id(item.id)
    }
}

/// Keeps optional detail in the view tree while its intrinsic height animates with focus.
private struct SystemCollapsibleLayout: Layout {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        let contentProposal = ProposedViewSize(width: proposal.width, height: nil)
        let contentSize = subview.sizeThatFits(contentProposal)
        return CGSize(
            width: proposal.width ?? contentSize.width,
            height: contentSize.height * progress
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        guard let subview = subviews.first else { return }
        subview.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: nil)
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
