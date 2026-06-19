import Foundation
import SwiftUI
import AppKit


struct HorizontalSplit<Leading: View, Trailing: View>: NSViewRepresentable {
    @Binding var presented: Bool
    @Binding var position: CGFloat

    let collapsedWidth: CGFloat
    let minLeadingWidth: CGFloat
    let minTrailingWidth: CGFloat
    let leading: Leading
    let trailing: Trailing

    init(
        presented: Binding<Bool>,
        position: Binding<CGFloat>,
        collapsedWidth: CGFloat = 0,
        minLeadingWidth: CGFloat = 0,
        minTrailingWidth: CGFloat = 0,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        _presented = presented
        _position = position
        self.collapsedWidth = collapsedWidth
        self.minLeadingWidth = minLeadingWidth
        self.minTrailingWidth = minTrailingWidth
        self.leading = leading()
        self.trailing = trailing()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> FillSplitView {
        let split = FillSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.delegate = context.coordinator
        split.arrangesAllSubviews = true
        split.addArrangedSubview(SplitHostingView(rootView: leading))
        split.addArrangedSubview(SplitHostingView(rootView: trailing))
        return split
    }

    func updateNSView(_ split: FillSplitView, context: Context) {
        (split.arrangedSubviews[0] as? SplitHostingView<Leading>)?.rootView = leading
        (split.arrangedSubviews[1] as? SplitHostingView<Trailing>)?.rootView = trailing
        context.coordinator.parent = self
        context.coordinator.apply(to: split)
    }

    @MainActor final class Coordinator: NSObject, NSSplitViewDelegate {
        var parent: HorizontalSplit
        private var lastAppliedPresented: Bool?
        private var lastBounds: CGFloat = 0

        init(_ parent: HorizontalSplit) {
            self.parent = parent
        }

        private var isCollapsed: Bool {
            !parent.presented
        }

        func apply(to split: NSSplitView) {
            guard split.bounds.width > 0, split.arrangedSubviews.count == 2 else { return }

            let total = split.bounds.width
            let presentedChanged = lastAppliedPresented != parent.presented
            let boundsChanged = abs(lastBounds - total) > 0.5
            guard presentedChanged || boundsChanged else { return }

            if presentedChanged, isCollapsed, let prev = lastAppliedPresented, prev == true {
                let liveTrailing = split.arrangedSubviews[1].frame.width
                if liveTrailing > parent.collapsedWidth + 1 {
                    let saved = max(liveTrailing, parent.minTrailingWidth)
                    if abs(parent.position - saved) > 0.5 {
                        parent.position = saved
                    }
                }
            }

            lastAppliedPresented = parent.presented
            lastBounds = total

            let divider = split.dividerThickness
            let savedOpenWidth = max(parent.position, parent.minTrailingWidth)
            let trailingWidth = isCollapsed ? parent.collapsedWidth : savedOpenWidth
            let leadingWidth = max(parent.minLeadingWidth, total - trailingWidth - divider)

            split.setPosition(leadingWidth, ofDividerAt: 0)
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

        func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
            false
        }

        func splitView(_ splitView: NSSplitView, constrainSplitPosition proposedPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            let total = splitView.bounds.width
            let divider = splitView.dividerThickness
            let minLeading = min(parent.minLeadingWidth, total)
            let maxLeading = parent.presented
                ? total - parent.minTrailingWidth - divider
                : total - parent.collapsedWidth - divider
            return min(max(proposedPosition, minLeading), max(minLeading, maxLeading))
        }

        func splitView(
            _ splitView: NSSplitView,
            effectiveRect proposedEffectiveRect: NSRect,
            forDrawnRect drawnRect: NSRect,
            ofDividerAt dividerIndex: Int
        ) -> NSRect {
            NSRect(
                x: drawnRect.minX - 8,
                y: drawnRect.minY,
                width: drawnRect.width + 16,
                height: drawnRect.height
            )
        }
    }
}
