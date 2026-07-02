import Foundation
import SwiftUI
import AppKit


final class FillSplitView: NSSplitView {
    override var dividerColor: NSColor { .clear }
}

final class SplitHostingView<Content: View>: NSHostingView<Content> {
    override var safeAreaInsets: NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}

struct VerticalSplit<Top: View, Bottom: View>: NSViewRepresentable {
    @Binding var position: CGFloat
    @Binding var presented: Bool

    let top: Top
    let bottom: Bottom
    let collapsedHeight: CGFloat
    let minTopHeight: CGFloat
    let minBottomHeight: CGFloat

    init(
        _ presented: Binding<Bool>,
        position: Binding<CGFloat>,
        collapsedHeight: CGFloat = 34,
        minTopHeight: CGFloat = 0,
        minBottomHeight: CGFloat = 0,
        @ViewBuilder top: () -> Top,
        @ViewBuilder bottom: () -> Bottom
    ) {
        _position = position
        _presented = presented
        self.collapsedHeight = collapsedHeight
        self.minTopHeight = minTopHeight
        self.minBottomHeight = minBottomHeight
        self.top = top()
        self.bottom = bottom()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> FillSplitView {
        let split = FillSplitView()
        split.isVertical = false
        split.dividerStyle = .thin
        split.delegate = context.coordinator
        split.arrangesAllSubviews = true
        split.addArrangedSubview(SplitHostingView(rootView: top))
        split.addArrangedSubview(SplitHostingView(rootView: bottom))
        return split
    }

    func updateNSView(_ split: FillSplitView, context: Context) {
        (split.arrangedSubviews[0] as? SplitHostingView<Top>)?.rootView = top
        (split.arrangedSubviews[1] as? SplitHostingView<Bottom>)?.rootView = bottom
        context.coordinator.parent = self
        context.coordinator.apply(to: split)
    }

    @MainActor final class Coordinator: NSObject, NSSplitViewDelegate {
        var parent: VerticalSplit
        private var lastAppliedPresented: Bool?
        private var lastBounds: CGFloat = 0
        private var isCollapsed: Bool { !parent.presented }

        init(_ parent: VerticalSplit) { self.parent = parent }

        func apply(to split: NSSplitView) {
            guard split.bounds.height > 0, split.arrangedSubviews.count == 2 else { return }

            let total = split.bounds.height
            let presentedChanged = lastAppliedPresented != parent.presented
            let boundsChanged = abs(lastBounds - total) > 0.5
            guard presentedChanged || boundsChanged else { return }

            if presentedChanged, isCollapsed, let prev = lastAppliedPresented, prev == true {
                let liveBottom = split.arrangedSubviews[1].frame.height
                if liveBottom > parent.collapsedHeight + 1 {
                    let saved = max(liveBottom, parent.minBottomHeight)
                    if abs(parent.position - saved) > 0.5 {
                        parent.position = saved
                    }
                }
            }

            lastAppliedPresented = parent.presented
            lastBounds = total

            let divider = split.dividerThickness
            let savedOpenHeight = max(parent.position, parent.minBottomHeight)
            let bottomHeight = isCollapsed ? parent.collapsedHeight : savedOpenHeight
            let topHeight = max(parent.minTopHeight, total - bottomHeight - divider)

            split.setPosition(topHeight, ofDividerAt: 0)
        }

        func splitViewDidResizeSubviews(_ notification: Notification) {
            guard let split = notification.object as? NSSplitView else { return }
            guard split.arrangedSubviews.count == 2 else { return }
            guard split.bounds.height > 0 else { return }
            guard parent.presented else { return }
            let bottomHeight = split.arrangedSubviews[1].frame.height
            guard bottomHeight > parent.collapsedHeight + 1 else { return }
            let clampedHeight = max(bottomHeight, parent.minBottomHeight)
            if abs(parent.position - clampedHeight) > 0.5 { parent.position = clampedHeight }
        }

        func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
            false
        }

        func splitView(_ splitView: NSSplitView, constrainSplitPosition proposedPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            let total = splitView.bounds.height
            let divider = splitView.dividerThickness
            let minTop = parent.minTopHeight
            let maxTop = parent.presented
                ? total - parent.minBottomHeight - divider
                : total - parent.collapsedHeight - divider
            return min(max(proposedPosition, minTop), maxTop)
        }

        func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
            NSRect(
                x: drawnRect.minX + 250,
                y: drawnRect.minY,
                width: max(0, drawnRect.width - 320),
                height: drawnRect.height + 34
            )
        }
    }
}

