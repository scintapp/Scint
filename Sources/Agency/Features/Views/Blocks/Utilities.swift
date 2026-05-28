import Foundation
import SwiftUI
import AppKit


struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

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
        collapsedHeight: CGFloat = 28,
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

        init(_ parent: VerticalSplit) {
            self.parent = parent
        }

        private var isCollapsed: Bool {
            !parent.presented
        }

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

            if abs(parent.position - clampedHeight) > 0.5 {
                parent.position = clampedHeight
            }
        }

        func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
            false
        }

        func splitView(
            _ splitView: NSSplitView,
            constrainSplitPosition proposedPosition: CGFloat,
            ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            let total = splitView.bounds.height
            let divider = splitView.dividerThickness
            let minTop = parent.minTopHeight

            let maxTop = parent.presented
                ? total - parent.minBottomHeight - divider
                : total - parent.collapsedHeight - divider

            return min(max(proposedPosition, minTop), maxTop)
        }

        func splitView(
            _ splitView: NSSplitView,
            effectiveRect proposedEffectiveRect: NSRect,
            forDrawnRect drawnRect: NSRect,
            ofDividerAt dividerIndex: Int
        ) -> NSRect {
            NSRect(
                x: drawnRect.minX + 120,
                y: drawnRect.minY,
                width: max(0, drawnRect.width - 200),
                height: drawnRect.height + 28
            )
        }
    }
}

struct HorizontalSplit<Leading: View, Trailing: View>: View {
    @Binding var presented: Bool
    @Binding var position: CGFloat
    @State private var dragStart: CGFloat?

    let collapsedWidth: CGFloat
    let minLeadingWidth: CGFloat
    let minTrailingWidth: CGFloat
    let leading: Leading
    let trailing: Trailing
    private let handleWidth: CGFloat = 9

    init(
        presented: Binding<Bool>,
        position: Binding<CGFloat>,
        collapsedWidth: CGFloat = 0,
        minLeadingWidth: CGFloat = 260,
        minTrailingWidth: CGFloat = 320,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        _position = position
        _presented = presented
        self.collapsedWidth = collapsedWidth
        self.minLeadingWidth = minLeadingWidth
        self.minTrailingWidth = minTrailingWidth
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        GeometryReader { proxy in
            let total = proxy.size.width
            let trailingWidth = trailingWidth(for: total)
            let trailingVisible = showsTrailing && trailingWidth > 0

            HStack(spacing: 0) {
                leading
                    .frame(
                        minWidth: min(minLeadingWidth, total),
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                    .layoutPriority(1)

                if trailingVisible {
                    HorizontalSplitHandle()
                        .frame(width: handleWidth)
                        .gesture(resizeGesture(totalWidth: total))

                    trailing
                        .frame(width: trailingWidth)
                        .frame(maxHeight: .infinity)
                        .clipped()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
        }
    }

    private var showsTrailing: Bool {
        presented || collapsedWidth > 0
    }

    private func trailingWidth(for totalWidth: CGFloat) -> CGFloat {
        guard showsTrailing else { return 0 }

        let desired = presented ? max(position, minTrailingWidth) : max(collapsedWidth, 0)
        let maxTrailing = max(0, totalWidth - min(minLeadingWidth, totalWidth) - handleWidth)
        return min(desired, maxTrailing)
    }

    private func resizeGesture(totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = max(position, minTrailingWidth)
                }

                let maxTrailing = max(0, totalWidth - min(minLeadingWidth, totalWidth) - handleWidth)
                let minTrailing = min(minTrailingWidth, maxTrailing)
                let nextWidth = (dragStart ?? position) - value.translation.width
                position = min(max(nextWidth, minTrailing), maxTrailing)
            }
            .onEnded { _ in
                dragStart = nil
            }
    }
}

private struct HorizontalSplitHandle: View {
    @State private var hovering = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(hovering ? Color.primary.opacity(0.06) : Color.clear)

            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)
        }
        .contentShape(Rectangle())
        .onHover { inside in
            hovering = inside
            if inside {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
