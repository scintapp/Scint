import AppKit
import SwiftUI
import ScintComponents


struct HSplitHandle: View {
    let onChanged: (DragGesture.Value) -> Void
    let onEnded: () -> Void
    let onAppear: () -> Void
    let onDisappear: () -> Void

    private let hitWidth: CGFloat = 8

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Style.Border.hairline)
                .frame(width: 0.5)

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
    private let minimumPaneWidth: CGFloat = 330

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
        if dragStart == nil { dragStart = trailingWidth > 0 ? trailingWidth : position.wrappedValue }
        let bounds = trailingBounds(total: availableWidth)
        let width = (dragStart ?? position.wrappedValue) - value.translation.width
        position.wrappedValue = min(max(width, bounds.lowerBound), bounds.upperBound)
    }
}
