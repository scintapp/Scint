import SwiftUI


private struct WorkspaceCanvasPosition: Identifiable {
    let item: ItemParams
    let parent: AnyHashable?
    let center: CGPoint

    var id: AnyHashable { item.id }
}

private struct WorkspaceCanvasMap {
    let nodes: [WorkspaceCanvasPosition]
    let size: CGSize
}

private struct WorkspaceCanvasNode: View {
    @GestureState private var translation: CGSize = .zero

    let item: ItemParams
    let selected: Bool
    let offset: CGSize
    let scale: CGFloat
    let onSelect: () -> Void
    let onMove: (CGSize) -> Void

    private var liveOffset: CGSize {
        .init(
            width: offset.width + translation.width / scale,
            height: offset.height + translation.height / scale
        )
    }

    var body: some View {
        let shape = Style.Shape.medium

        HStack(alignment: .center, spacing: Style.Spacing.lg) {
            if let ref = item.ref {
                Iconography.icon(for: ref, size: Style.Dimension.iconLarge)
                    .frame(width: Style.Dimension.control, height: Style.Dimension.control)
            }

            VStack(alignment: .leading, spacing: Style.Spacing.xs) {
                Text(item.name)
                    .font(Typography.cardHeading)
                    .foregroundStyle(Style.Foreground.base)
                    .lineLimit(Style.Limit.singleLine)

                if let harness = item.value, !harness.isEmpty {
                    Text(harness)
                        .font(Typography.cardDetail())
                        .foregroundStyle(Style.Foreground.muted)
                        .lineLimit(Style.Limit.singleLine)
                } else if !item.description.isEmpty {
                    Text(item.description)
                        .font(Typography.cardDetail())
                        .foregroundStyle(Style.Foreground.faint)
                        .lineLimit(Style.Limit.doubleLine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: Style.Spacing.md) {
                Iconography.Icon(
                    symbol: "arrow.up.and.down.and.arrow.left.and.right",
                    tint: Style.Tint.space,
                    sizing: Style.Dimension.icon,
                    selected: false
                )
                .frame(width: Style.Dimension.icon, height: Style.Dimension.icon)

                if let count = item.count, count > 0 {
                    Text("\(count)")
                        .font(Typography.badge)
                        .foregroundStyle(Style.Foreground.faint)
                        .padding(.horizontal, Style.Spacing.md)
                        .padding(.vertical, Style.Spacing.sm)
                        .background(Style.Shape.capsule.fill(Style.Background.control))
                }
            }
        }
        .padding(Style.Spacing.xl)
        .frame(
            width: Style.Dimension.canvasNode.width,
            height: Style.Dimension.canvasNode.height,
            alignment: .leading
        )
        .background(shape.fill(Style.Background.raised))
        .overlay {
            shape.stroke(
                selected ? Style.Tint.space : Style.Border.raised,
                lineWidth: Style.Dimension.border
            )
        }
        .contentShape(shape)
        .shadow(color: .black.opacity(Style.Opacity.faint), radius: Style.Spacing.md, y: Style.Spacing.sm)
        .offset(liveOffset)
        .onTapGesture(perform: onSelect)
        .gesture(
            DragGesture(minimumDistance: Style.Spacing.xs)
                .updating($translation) { value, state, _ in state = value.translation }
                .onEnded { value in
                    onMove(
                        .init(
                            width: offset.width + value.translation.width / scale,
                            height: offset.height + value.translation.height / scale
                        )
                    )
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.name)
        .accessibilityHint("Select or drag to reposition this workspace node")
    }
}

struct ChartsSurface: Surface {
    var panel: any Panel
    var model: any Model

    @GestureState private var canvasTranslation: CGSize = .zero
    @GestureState private var magnification: CGFloat = Style.Scale.identity

    private var storedScale: CGFloat {
        panel.state["workspace-canvas-scale", as: CGFloat.self] ?? Style.Scale.identity
    }

    private var storedPan: CGSize {
        panel.state["workspace-canvas-pan", as: CGSize.self] ?? .zero
    }

    private var canvasScale: CGFloat { clamped(storedScale * magnification) }

    private var canvasPan: CGSize {
        .init(
            width: storedPan.width + canvasTranslation.width,
            height: storedPan.height + canvasTranslation.height
        )
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, Style.Scale.minimum), Style.Scale.maximum)
    }

    private func offsetKey(for item: ItemParams) -> AnyHashable {
        if let ref = item.ref { return AnyHashable("workspace-canvas-node-\(ref.id.uuidString)") }
        return AnyHashable("workspace-canvas-node-\(item.id)")
    }

    private func nodeOffset(for item: ItemParams) -> CGSize {
        panel.state[offsetKey(for: item), as: CGSize.self] ?? .zero
    }

    private func setNodeOffset(_ value: CGSize, for item: ItemParams) {
        panel.state[offsetKey(for: item), as: CGSize.self] = value
    }

    private func setScale(_ value: CGFloat) {
        panel.state["workspace-canvas-scale", as: CGFloat.self] = clamped(value)
    }

    private func setPan(_ value: CGSize) {
        panel.state["workspace-canvas-pan", as: CGSize.self] = value
    }

    private func layout(_ root: ItemParams) -> WorkspaceCanvasMap {
        let node = Style.Dimension.canvasNode
        let padding = Style.Dimension.canvasPadding
        var cursor = padding
        var deepest = 0
        var nodes: [WorkspaceCanvasPosition] = []

        @discardableResult
        func place(_ item: ItemParams, parent: AnyHashable?, depth: Int) -> CGFloat {
            deepest = max(deepest, depth)
            let children = item.items.map { place($0, parent: item.id, depth: depth + 1) }
            let x: CGFloat

            if let first = children.first, let last = children.last {
                x = (first + last) / 2
            } else {
                x = cursor + node.width / 2
                cursor += node.width + Style.Dimension.canvasSiblingGap
            }

            let y = padding + node.height / 2
                + CGFloat(depth) * (node.height + Style.Dimension.canvasLevelGap)
            nodes.append(.init(item: item, parent: parent, center: .init(x: x, y: y)))
            return x
        }

        place(root, parent: nil, depth: 0)
        let width = max(
            cursor - Style.Dimension.canvasSiblingGap + padding,
            node.width + padding * 2
        )
        let height = padding * 2 + node.height
            + CGFloat(deepest) * (node.height + Style.Dimension.canvasLevelGap)
        return .init(nodes: nodes, size: .init(width: width, height: height))
    }

    private func canvasDrag() -> some Gesture {
        DragGesture(minimumDistance: Style.Spacing.sm)
            .updating($canvasTranslation) { value, state, _ in state = value.translation }
            .onEnded { value in
                setPan(
                    .init(
                        width: storedPan.width + value.translation.width,
                        height: storedPan.height + value.translation.height
                    )
                )
            }
    }

    private func zoomGesture() -> some Gesture {
        MagnifyGesture(minimumScaleDelta: Style.Scale.step / 10)
            .updating($magnification) { value, state, _ in state = value.magnification }
            .onEnded { value in setScale(storedScale * value.magnification) }
    }

    @ViewBuilder private func connections(_ map: WorkspaceCanvasMap) -> some View {
        let positions = Dictionary(uniqueKeysWithValues: map.nodes.map { value in
            let offset = nodeOffset(for: value.item)
            return (
                value.id,
                CGPoint(x: value.center.x + offset.width, y: value.center.y + offset.height)
            )
        })

        Canvas { context, _ in
            for value in map.nodes {
                guard
                    let parent = value.parent,
                    let source = positions[parent],
                    let destination = positions[value.id]
                else { continue }

                let start = CGPoint(
                    x: source.x,
                    y: source.y + Style.Dimension.canvasNode.height / 2
                )
                let end = CGPoint(
                    x: destination.x,
                    y: destination.y - Style.Dimension.canvasNode.height / 2
                )
                let midpoint = (start.y + end.y) / 2
                var path = Path()
                path.move(to: start)
                path.addLine(to: .init(x: start.x, y: midpoint))
                path.addLine(to: .init(x: end.x, y: midpoint))
                path.addLine(to: end)
                context.stroke(
                    path,
                    with: .color(Style.Border.group),
                    lineWidth: Style.Dimension.border
                )
            }
        }
        .frame(width: map.size.width, height: map.size.height)
        .allowsHitTesting(false)
    }

    @ViewBuilder private func control(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Iconography.Icon(
                symbol: symbol,
                tint: Style.Tint.space,
                sizing: Style.Dimension.icon,
                selected: true
            )
            .frame(width: Style.Dimension.control, height: Style.Dimension.control)
            .contentShape(Style.Shape.small)
            .background(Style.Shape.small.fill(Style.Background.control))
            .overlay {
                Style.Shape.small.stroke(Style.Border.raised, lineWidth: Style.Dimension.border)
            }
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    var body: some View {
        let params = WorkspaceHierarchyMapper.parameters(model)
        let controls = WorkspaceHierarchyMapper.controls(model)

        GeometryReader { geometry in
            if let root = params.sections.first?.items.first {
                let map = layout(root)
                let x = (geometry.size.width - map.size.width) / 2 + canvasPan.width
                let y = (geometry.size.height - map.size.height) / 2 + canvasPan.height

                ZStack(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {
                        connections(map)

                        ForEach(map.nodes) { value in
                            WorkspaceCanvasNode(
                                item: value.item,
                                selected: controls.selected?(value.item) ?? false,
                                offset: nodeOffset(for: value.item),
                                scale: canvasScale,
                                onSelect: { controls.onSelect?(value.item) },
                                onMove: { setNodeOffset($0, for: value.item) }
                            )
                            .position(value.center)
                        }
                    }
                    .frame(width: map.size.width, height: map.size.height, alignment: .topLeading)
                    .scaleEffect(canvasScale, anchor: .center)
                    .offset(x: x, y: y)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
                .clipped()
                .gesture(canvasDrag())
                .simultaneousGesture(zoomGesture())
                .overlay(alignment: .topTrailing) {
                    VStack(spacing: Style.Spacing.sm) {
                        control("plus", help: "Zoom in") {
                            setScale(storedScale + Style.Scale.step)
                        }
                        .keyboardShortcut("+", modifiers: .command)

                        control("minus", help: "Zoom out") {
                            setScale(storedScale - Style.Scale.step)
                        }
                        .keyboardShortcut("-", modifiers: .command)

                        control("arrow.up.left.and.arrow.down.right", help: "Fit hierarchy") {
                            let available = CGSize(
                                width: max(
                                    geometry.size.width - Style.Dimension.canvasPadding * 2,
                                    Style.Dimension.canvasNode.width
                                ),
                                height: max(
                                    geometry.size.height - Style.Dimension.canvasPadding * 2,
                                    Style.Dimension.canvasNode.height
                                )
                            )
                            let fitted = min(
                                available.width / map.size.width,
                                available.height / map.size.height,
                                Style.Scale.identity
                            )
                            setScale(fitted)
                            setPan(.zero)
                        }
                        .keyboardShortcut("0", modifiers: .command)
                    }
                    .padding(Style.Spacing.xl)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Style.Background.page)
    }
}
