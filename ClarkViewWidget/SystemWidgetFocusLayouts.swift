//
//  SystemWidgetFocusLayouts.swift
//  ClarkViewWidget
//

import SwiftUI

/// Reflows one stable set of item views between compact and focused card arrangements.
struct SystemFocusItemLayout: Layout {
    var primaryProgress: CGFloat

    private let compactContentRatio: CGFloat = 0.7
    private let columnSpacing: CGFloat = 12
    private let compactSpacing: CGFloat = 4
    private let primarySpacing: CGFloat = 10

    var animatableData: CGFloat {
        get { primaryProgress }
        set { primaryProgress = newValue }
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        guard subviews.count == 4 else { return .zero }

        let width = proposal.width ?? idealWidth(for: subviews)
        let metrics = metrics(for: width, subviews: subviews)
        let compactContentHeight = metrics.timeSize.height
            + compactSpacing
            + metrics.mainTextSize.height
        let compactHeight = max(compactContentHeight, metrics.actionSize.height)
        let naturalPrimaryHeight = metrics.mainTextSize.height
            + primarySpacing
            + metrics.subTextSize.height
            + primarySpacing
            + metrics.timeSize.height
        let proposedHeight = proposal.height.flatMap { $0.isFinite ? $0 : nil }
        let primaryHeight = max(naturalPrimaryHeight, proposedHeight ?? naturalPrimaryHeight)

        return CGSize(
            width: width,
            height: interpolate(from: compactHeight, to: primaryHeight)
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        guard subviews.count == 4 else { return }

        let metrics = metrics(for: bounds.width, subviews: subviews)
        let compactContentHeight = metrics.timeSize.height
            + compactSpacing
            + metrics.mainTextSize.height
        let compactHeight = max(compactContentHeight, metrics.actionSize.height)
        let compactContentY = (compactHeight - compactContentHeight) / 2

        let timeY = interpolate(
            from: compactContentY + metrics.mainTextSize.height + compactSpacing,
            to: bounds.height - metrics.timeSize.height
        )
        let mainTextY = interpolate(
            from: compactContentY,
            to: 0
        )
        let subTextX = interpolate(
            from: metrics.compactContentWidth + columnSpacing,
            to: 0
        )
        let subTextY = interpolate(
            from: (compactHeight - metrics.subTextSize.height) / 2,
            to: metrics.mainTextSize.height + primarySpacing
        )
        let actionX = metrics.compactContentWidth + columnSpacing
        let actionY = (compactHeight - metrics.actionSize.height) / 2

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + timeY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: metrics.contentWidth, height: nil)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + mainTextY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: metrics.contentWidth, height: nil)
        )
        subviews[2].place(
            at: CGPoint(x: bounds.minX + subTextX, y: bounds.minY + subTextY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: metrics.detailWidth, height: nil)
        )
        subviews[3].place(
            at: CGPoint(x: bounds.minX + actionX, y: bounds.minY + actionY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: metrics.compactDetailWidth, height: nil)
        )
    }

    private func metrics(for width: CGFloat, subviews: Subviews) -> Metrics {
        let compactAvailableWidth = max(0, width - columnSpacing)
        let compactContentWidth = compactAvailableWidth * compactContentRatio
        let compactDetailWidth = compactAvailableWidth - compactContentWidth
        let contentWidth = interpolate(from: compactContentWidth, to: width)
        let detailWidth = interpolate(from: compactDetailWidth, to: width)
        let timeSize = subviews[0].sizeThatFits(
            ProposedViewSize(width: contentWidth, height: nil)
        )
        let mainTextSize = subviews[1].sizeThatFits(
            ProposedViewSize(width: contentWidth, height: nil)
        )
        let subTextSize = subviews[2].sizeThatFits(
            ProposedViewSize(width: detailWidth, height: nil)
        )
        let actionSize = subviews[3].sizeThatFits(
            ProposedViewSize(width: compactDetailWidth, height: nil)
        )

        return Metrics(
            compactContentWidth: compactContentWidth,
            compactDetailWidth: compactDetailWidth,
            contentWidth: contentWidth,
            detailWidth: detailWidth,
            timeSize: timeSize,
            mainTextSize: mainTextSize,
            subTextSize: subTextSize,
            actionSize: actionSize
        )
    }

    private func idealWidth(for subviews: Subviews) -> CGFloat {
        subviews.reduce(CGFloat.zero) { width, subview in
            max(width, subview.sizeThatFits(.unspecified).width)
        }
    }

    private func interpolate(from start: CGFloat, to end: CGFloat) -> CGFloat {
        start + ((end - start) * primaryProgress)
    }

    private struct Metrics {
        let compactContentWidth: CGFloat
        let compactDetailWidth: CGFloat
        let contentWidth: CGFloat
        let detailWidth: CGFloat
        let timeSize: CGSize
        let mainTextSize: CGSize
        let subTextSize: CGSize
        let actionSize: CGSize
    }
}
