import Foundation
import SwiftUI
import AppKit


struct HorizontalSplitHandleStyle {
    var color: NSColor
    var thickness: CGFloat?
    var hitOutset: CGFloat
    var visibleInsets: NSEdgeInsets
    var dividerStyle: NSSplitView.DividerStyle

    init(
        color: NSColor = .white.withAlphaComponent(0.028),
        thickness: CGFloat? = nil,
        hitOutset: CGFloat = 2,
        visibleInsets: NSEdgeInsets = NSEdgeInsets(top: 84, left: 0, bottom: 00, right: 0),
        dividerStyle: NSSplitView.DividerStyle = .thin
    ) {
        self.color = color
        self.thickness = thickness.map { max(0, $0) }
        self.hitOutset = max(0, hitOutset)
        self.visibleInsets = visibleInsets
        self.dividerStyle = dividerStyle
    }

    static let hidden = HorizontalSplitHandleStyle(color: .clear)
    static let separator = HorizontalSplitHandleStyle()
}

struct HorizontalSplit<Leading: View, Trailing: View>: NSViewRepresentable {
    @Binding var presented: Bool
    @Binding var position: CGFloat
    let collapsedWidth: CGFloat
    let minLeadingWidth: CGFloat
    let minTrailingWidth: CGFloat
    let handleStyle: HorizontalSplitHandleStyle
    let leading: Leading
    let trailing: Trailing

    init(
        _ presented: Binding<Bool>,
        _ position: Binding<CGFloat>,
        collapsedWidth: CGFloat = 0,
        minLeadingWidth: CGFloat = 0,
        minTrailingWidth: CGFloat = 0,
        handleStyle: HorizontalSplitHandleStyle = .separator,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        _presented = presented
        _position = position
        self.collapsedWidth = collapsedWidth
        self.minLeadingWidth = minLeadingWidth
        self.minTrailingWidth = minTrailingWidth
        self.handleStyle = handleStyle
        self.leading = leading()
        self.trailing = trailing()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // Keep enabled: this prevents the divider/handle from intersecting the toolbar.
    func makeNSView(context: Context) -> FillSplitView {
        let split = FillSplitView()
        split.isVertical = true
        split.clipsVerticalDividerToSafeArea = true
        applyHandleStyle(to: split)
        split.delegate = context.coordinator
        split.arrangesAllSubviews = true
        split.addArrangedSubview(SplitHostingView(rootView: leading))
        split.addArrangedSubview(SplitHostingView(rootView: trailing))
        return split
    }

    func updateNSView(_ split: FillSplitView, context: Context) {
        applyHandleStyle(to: split)
        (split.arrangedSubviews[0] as? SplitHostingView<Leading>)?.rootView = leading
        (split.arrangedSubviews[1] as? SplitHostingView<Trailing>)?.rootView = trailing
        context.coordinator.parent = self
        context.coordinator.apply(to: split)
    }

    // Keep enabled: this prevents the divider/handle from intersecting the toolbar.
    private func applyHandleStyle(to split: FillSplitView) {
        split.clipsVerticalDividerToSafeArea = true
        split.dividerStyle = handleStyle.dividerStyle
        split.fillDividerColor = handleStyle.color
        split.fillDividerInsets = handleStyle.visibleInsets
        split.fillDividerThickness = handleStyle.thickness
    }

    @MainActor final class Coordinator: NSObject, NSSplitViewDelegate {
        var parent: HorizontalSplit
        private var lastAppliedPresented: Bool?
        private var lastBounds: CGFloat = 0
        private var lastPosition: CGFloat?
        private var lastCollapsedWidth: CGFloat?
        private var lastMinLeadingWidth: CGFloat?
        private var lastMinTrailingWidth: CGFloat?
        private var lastDividerThickness: CGFloat?

        init(_ parent: HorizontalSplit) { self.parent = parent }

        private var isCollapsed: Bool { !parent.presented }

        func apply(to split: NSSplitView) {
            guard split.bounds.width > 0, split.arrangedSubviews.count == 2 else { return }
            let trailingSubview = split.arrangedSubviews[1]
            let total = split.bounds.width
            let presentedChanged = lastAppliedPresented != parent.presented
            let boundsChanged = abs(lastBounds - total) > 0.5
            let positionChanged = lastPosition.map { abs($0 - parent.position) > 0.5 } ?? true
            let collapsedWidthChanged = lastCollapsedWidth.map { abs($0 - parent.collapsedWidth) > 0.5 } ?? true
            let minLeadingWidthChanged = lastMinLeadingWidth.map { abs($0 - parent.minLeadingWidth) > 0.5 } ?? true
            let minTrailingWidthChanged = lastMinTrailingWidth.map { abs($0 - parent.minTrailingWidth) > 0.5 } ?? true
            let dividerThickness = split.dividerThickness
            let dividerThicknessChanged = lastDividerThickness.map { abs($0 - dividerThickness) > 0.5 } ?? true

            guard presentedChanged
                    || boundsChanged
                    || positionChanged
                    || collapsedWidthChanged
                    || minLeadingWidthChanged
                    || minTrailingWidthChanged
                    || dividerThicknessChanged
            else { return }

            if presentedChanged, isCollapsed, let prev = lastAppliedPresented, prev == true {
                let liveTrailing = trailingSubview.frame.width
                if liveTrailing > parent.collapsedWidth + 1 {
                    let saved = max(liveTrailing, parent.minTrailingWidth)
                    if abs(parent.position - saved) > 0.5 { parent.position = saved }
                }
            }

            if isCollapsed {
                if let split = split as? FillSplitView { split.fillDividerColor = .clear }
                if !trailingSubview.isHidden { trailingSubview.isHidden = true }
                remember(total: total, dividerThickness: dividerThickness)
                return
            }

            if let split = split as? FillSplitView { split.fillDividerColor = parent.handleStyle.color }
            if trailingSubview.isHidden { trailingSubview.isHidden = false }
            let savedOpenWidth = max(parent.position, parent.minTrailingWidth)
            let leadingWidth = max(parent.minLeadingWidth, total - savedOpenWidth - dividerThickness)
            split.setPosition(leadingWidth, ofDividerAt: 0)
            remember(total: total, dividerThickness: dividerThickness)
        }

        private func remember(total: CGFloat, dividerThickness: CGFloat) {
            lastAppliedPresented = parent.presented
            lastBounds = total
            lastPosition = parent.position
            lastCollapsedWidth = parent.collapsedWidth
            lastMinLeadingWidth = parent.minLeadingWidth
            lastMinTrailingWidth = parent.minTrailingWidth
            lastDividerThickness = dividerThickness
        }

        func splitViewDidResizeSubviews(_ notification: Notification) {
            guard let split = notification.object as? NSSplitView else { return }
            guard split.arrangedSubviews.count == 2 else { return }
            guard split.bounds.width > 0 else { return }
            guard parent.presented else { return }
            let trailingWidth = split.arrangedSubviews[1].frame.width
            guard trailingWidth > parent.collapsedWidth + 1 else { return }
            let clampedWidth = max(trailingWidth, parent.minTrailingWidth)
            if abs(parent.position - clampedWidth) > 0.5 { parent.position = clampedWidth }
        }

        func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool { false }

        func splitView(_ splitView: NSSplitView, constrainSplitPosition proposedPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            let total = splitView.bounds.width
            let divider = splitView.dividerThickness
            let minLeading = min(parent.minLeadingWidth, total)
            let maxLeading = parent.presented
            ? total - parent.minTrailingWidth - divider
            : total - parent.collapsedWidth - divider
            return min(max(proposedPosition, minLeading), max(minLeading, maxLeading))
        }
    }
}
