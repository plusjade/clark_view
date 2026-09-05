//
//  SystemWidgetFocusLayouts.swift
//  ClarkViewWidget
//

import SwiftUI

/// Moves the role detail between a compact action column and the focused item's full-width footer.
struct SystemFocusItemLayout: Layout {
    var primaryProgress: CGFloat

    private let compactContentRatio: CGFloat = 0.7
    private let columnSpacing: CGFloat = 12
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
        guard subviews.count == 2 else { return .zero }

        let width = proposal.width ?? idealWidth(for: subviews)
        let metrics = metrics(for: width, subviews: subviews)
        let compactHeight = max(metrics.contentSize.height, metrics.detailSize.height)
        let primaryHeight = metrics.contentSize.height + primarySpacing + metrics.detailSize.height

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
        guard subviews.count == 2 else { return }

        let metrics = metrics(for: bounds.width, subviews: subviews)
        let compactHeight = max(metrics.contentSize.height, metrics.detailSize.height)
        let contentY = interpolate(
            from: (compactHeight - metrics.contentSize.height) / 2,
            to: 0
        )
        let detailX = interpolate(
            from: metrics.compactContentWidth + columnSpacing,
            to: 0
        )
        let detailY = interpolate(
            from: (compactHeight - metrics.detailSize.height) / 2,
            to: metrics.contentSize.height + primarySpacing
        )

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + contentY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: metrics.contentWidth, height: nil)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX + detailX, y: bounds.minY + detailY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: metrics.detailWidth, height: nil)
        )
    }

    private func metrics(for width: CGFloat, subviews: Subviews) -> Metrics {
        let compactAvailableWidth = max(0, width - columnSpacing)
        let compactContentWidth = compactAvailableWidth * compactContentRatio
        let compactDetailWidth = compactAvailableWidth - compactContentWidth
        let contentWidth = interpolate(from: compactContentWidth, to: width)
        let detailWidth = interpolate(from: compactDetailWidth, to: width)
        let contentSize = subviews[0].sizeThatFits(
            ProposedViewSize(width: contentWidth, height: nil)
        )
        let detailSize = subviews[1].sizeThatFits(
            ProposedViewSize(width: detailWidth, height: nil)
        )

        return Metrics(
            compactContentWidth: compactContentWidth,
            contentWidth: contentWidth,
            detailWidth: detailWidth,
            contentSize: contentSize,
            detailSize: detailSize
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
        let contentWidth: CGFloat
        let detailWidth: CGFloat
        let contentSize: CGSize
        let detailSize: CGSize
    }
}

/// Crossfades role-specific detail while its intrinsic height follows the focus animation.
struct SystemRoleDetailLayout: Layout {
    var primaryProgress: CGFloat

    var animatableData: CGFloat {
        get { primaryProgress }
        set { primaryProgress = newValue }
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let contentProposal = ProposedViewSize(width: proposal.width, height: nil)
        let primarySize = subviews[0].sizeThatFits(contentProposal)
        let secondarySize = subviews[1].sizeThatFits(contentProposal)
        return CGSize(
            width: proposal.width ?? max(primarySize.width, secondarySize.width),
            height: secondarySize.height
                + ((primarySize.height - secondarySize.height) * primaryProgress)
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let contentProposal = ProposedViewSize(width: bounds.width, height: nil)
        for subview in subviews {
            subview.place(at: bounds.origin, anchor: .topLeading, proposal: contentProposal)
        }
    }
}
