import Foundation
import SwiftUI
import AppKit


final class FillSplitView: NSSplitView {
    var fillDividerColor: NSColor = .clear {
        didSet { needsDisplay = true }
    }

    var clipsVerticalDividerToSafeArea = false {
        didSet { needsDisplay = true }
    }

    var fillDividerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) {
        didSet { needsDisplay = true }
    }

    var fillDividerThickness: CGFloat? {
        didSet {
            needsLayout = true
            needsDisplay = true
        }
    }

    override var dividerColor: NSColor { fillDividerColor }
    override var dividerThickness: CGFloat { fillDividerThickness ?? super.dividerThickness }

    override func drawDivider(in rect: NSRect) {
        fillDividerColor.setFill()
        dividerVisibleRect(for: rect).fill()
    }

    func dividerVisibleRect(for rect: NSRect) -> NSRect {
        insetRect(rect, by: resolvedDividerInsets)
    }

    func insetRect(_ rect: NSRect, by insets: NSEdgeInsets) -> NSRect {
        let yInset = isFlipped ? insets.top : insets.bottom
        return NSRect(
            x: rect.minX + insets.left,
            y: rect.minY + yInset,
            width: max(0, rect.width - insets.left - insets.right),
            height: max(0, rect.height - insets.top - insets.bottom)
        )
    }

    private var resolvedDividerInsets: NSEdgeInsets {
        var insets = fillDividerInsets
        if clipsVerticalDividerToSafeArea, isVertical {
            insets.top = max(insets.top, safeAreaInsets.top)
        }
        return insets
    }
}

final class SplitHostingView<Content: View>: NSHostingView<Content> {}

struct VSplit<Top: View, Bottom: View>: NSViewRepresentable {
    @Binding var position: CGFloat
    @Binding var presented: Bool

    let top: Top
    let bottom: Bottom
    let collapsedHeight: CGFloat
    let minTopHeight: CGFloat
    let minBottomHeight: CGFloat

    init(
        _ presented: Binding<Bool>,
        _ position: Binding<CGFloat>,
        collapsedHeight: CGFloat = 30,
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

    func makeNSView(context: Self.Context) -> FillSplitView {
        let split = FillSplitView()
        split.isVertical = false
        split.dividerStyle = .thin
        split.delegate = context.coordinator
        split.arrangesAllSubviews = true
        split.addArrangedSubview(SplitHostingView(rootView: top))
        split.addArrangedSubview(SplitHostingView(rootView: bottom))
        return split
    }

    func updateNSView(_ split: FillSplitView, context: Self.Context) {
        (split.arrangedSubviews[0] as? SplitHostingView<Top>)?.rootView = top
        (split.arrangedSubviews[1] as? SplitHostingView<Bottom>)?.rootView = bottom
        context.coordinator.parent = self
        context.coordinator.apply(to: split)
    }

    @MainActor final class Coordinator: NSObject, NSSplitViewDelegate {
        var parent: VSplit
        private var lastAppliedPresented: Bool?
        private var lastBounds: CGFloat = 0
        private var isCollapsed: Bool { !parent.presented }

        init(_ parent: VSplit) { self.parent = parent }

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
            guard bottomHeight > parent.collapsedHeight else { return }
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
                height: drawnRect.height + 30
            )
        }
    }
}

struct HSplitHandle: View {
    let onChanged: (DragGesture.Value) -> Void
    let onEnded: () -> Void
    let onAppear: () -> Void
    let onDisappear: () -> Void

    private let hitWidth: CGFloat = 8

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Style.Border.card)
                .frame(width: 1)

            Color.clear
                .frame(width: hitWidth)
                .contentShape(Rectangle())
        }
        .frame(width: hitWidth)
        .frame(maxHeight: .infinity, alignment: .leading)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged(onChanged)
                .onEnded { _ in onEnded() }
        )
        .onContinuousHover { phase in
            switch phase {
                case .active(_): NSCursor.resizeLeftRight.set()
                case .ended: NSCursor.arrow.set()
            }
        }
        .onAppear(perform: onAppear)
        .onDisappear {
            NSCursor.arrow.set()
            onDisappear()
        }
    }
}

struct HSplit<Leading: View, Trailing: View>: View {
    @Binding private var presented: Bool
    @State private var availableWidth: CGFloat = 0
    @State private var trailingWidth: CGFloat = 0
    @State private var dragStart: CGFloat?
    @State private var handlePresented = false

    private let position: Binding<CGFloat>
    private let leading: Leading
    private let trailing: (HSplitHandle) -> Trailing
    private let minimumPaneWidth: CGFloat = 280

    init(
        _ presented: Binding<Bool>,
        _ position: Binding<CGFloat>,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: @escaping (HSplitHandle) -> Trailing
    ) {
        _presented = presented
        self.position = position
        self.leading = leading()
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)

            if presented {
                trailing(handle)
                    .frame(maxHeight: .infinity)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.width
                    } action: { width in
                        trailingWidth = width
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            availableWidth = width
            if handlePresented { normalize(within: width) }
        }
        .animation(.easeInOut(duration: 0.18), value: presented)
    }

    private var handle: HSplitHandle {
        HSplitHandle(
            onChanged: resize,
            onEnded: { dragStart = nil },
            onAppear: {
                handlePresented = true
                normalize(within: availableWidth)
            },
            onDisappear: { handlePresented = false }
        )
    }

    private func trailingBounds(total: CGFloat) -> ClosedRange<CGFloat> {
        let minimum = min(minimumPaneWidth, total / 2)
        return minimum...max(minimum, total - minimum)
    }

    private func normalize(within total: CGFloat) {
        guard total > 0 else { return }
        let bounds = trailingBounds(total: total)
        let requested = position.wrappedValue > 0 ? position.wrappedValue : total / 2
        let width = min(max(requested, bounds.lowerBound), bounds.upperBound)
        if abs(position.wrappedValue - width) > 0.5 { position.wrappedValue = width }
    }

    private func resize(_ value: DragGesture.Value) {
        guard availableWidth > 0 else { return }
        if dragStart == nil {
            dragStart = trailingWidth > 0 ? trailingWidth : position.wrappedValue
        }

        let bounds = trailingBounds(total: availableWidth)
        let width = (dragStart ?? position.wrappedValue) - value.translation.width
        position.wrappedValue = min(max(width, bounds.lowerBound), bounds.upperBound)
    }
}
