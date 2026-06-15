import Foundation
import SwiftUI
import AppKit


struct HorizontalSplit<Leading: View, Trailing: View>: View {
    @Binding var presented: Bool
    @Binding var position: CGFloat
    @State private var dragStart: CGFloat?
    @State private var dragTotal: CGFloat?

    let collapsedWidth: CGFloat
    let minLeadingWidth: CGFloat
    let minTrailingWidth: CGFloat
    let leading: Leading
    let trailing: Trailing
    private let handleWidth: CGFloat = 2

    init(
        presented: Binding<Bool>,
        position: Binding<CGFloat>,
        collapsedWidth: CGFloat = 0,
        minLeadingWidth: CGFloat = 100,
        minTrailingWidth: CGFloat = 100,
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

    // Bounds for the trailing pane given a container width.
    private func trailingBounds(for totalWidth: CGFloat) -> (min: CGFloat, max: CGFloat) {
        let maxTrailing = max(0, totalWidth - min(minLeadingWidth, totalWidth) - handleWidth)
        let minTrailing = min(minTrailingWidth, maxTrailing)
        return (minTrailing, maxTrailing)
    }

    // Single source of truth: render whatever `position` says, clamped once.
    private func trailingWidth(for totalWidth: CGFloat) -> CGFloat {
        guard showsTrailing else { return 0 }

        if !presented {
            return min(max(collapsedWidth, 0), totalWidth)
        }

        let bounds = trailingBounds(for: totalWidth)
        return min(max(position, bounds.min), bounds.max)
    }

    private func resizeGesture(totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Pin the container width and starting position for the whole drag,
                // so mid-drag relayout can't feed back into the math.
                if dragStart == nil {
                    dragTotal = totalWidth
                    dragStart = trailingWidth(for: totalWidth)
                }

                let activeTotal = dragTotal ?? totalWidth
                let bounds = trailingBounds(for: activeTotal)
                let nextWidth = (dragStart ?? position) - value.translation.width
                position = min(max(nextWidth, bounds.min), bounds.max)
            }
            .onEnded { _ in
                dragStart = nil
                dragTotal = nil
            }
    }
}

private struct HorizontalSplitHandle: View {
    @State private var hovering = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(hovering ? Color.primary.opacity(0.00) : Color.clear)

            Rectangle()
                .fill(Color(nsColor: .separatorColor)).opacity(0.0)
                .frame(width: 2)
        }
        .contentShape(Rectangle())
    }
}
