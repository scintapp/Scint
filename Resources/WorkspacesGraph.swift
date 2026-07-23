import AgencyRuntime
import SwiftUI


struct WorkspacesGraph: View {
    var body: some View {
        let graph = WorkspaceGraphSnapshot()

        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for edge in graph.edges {
                        guard let source = graph.positions[edge.source],
                              let target = graph.positions[edge.target]
                        else { continue }

                        let start = CGPoint(x: source.x + WorkspaceGraphSnapshot.nodeWidth / 2, y: source.y)
                        let end = CGPoint(x: target.x - WorkspaceGraphSnapshot.nodeWidth / 2, y: target.y)
                        let distance = max(40, abs(end.x - start.x) * 0.45)
                        var path = Path()
                        path.move(to: start)
                        path.addCurve(
                            to: end,
                            control1: CGPoint(x: start.x + distance, y: start.y),
                            control2: CGPoint(x: end.x - distance, y: end.y)
                        )
                        context.stroke(
                            path,
                            with: .color(edge.route ? Design.Tint.traverse.opacity(0.7) : Design.Foreground.quaternary.opacity(0.5)),
                            style: StrokeStyle(lineWidth: edge.route ? 1.5 : 1, dash: edge.route ? [5, 5] : [])
                        )
                    }
                }

                ForEach(graph.nodes) { node in
                    WorkspaceGraphNode(node: node)
                        .position(node.position)
                }
            }
            .frame(width: graph.size.width, height: graph.size.height, alignment: .topLeading)
        }
        .overlay(alignment: .topLeading) {
            HStack(spacing: 14) {
                Label("Containment", systemImage: "line.diagonal")
                Label("Route", systemImage: "line.diagonal.arrow")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Design.Foreground.tertiary)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .glassEffect(.regular, in: Capsule())
            .padding(12)
        }
    }
}

private struct WorkspaceGraphNode: View {
    let node: WorkspaceGraphSnapshot.Node

    var body: some View {
        HStack(spacing: 10) {
            Iconography.icon(for: node.ref, size: 16)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(node.ref.descriptor.name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Design.Foreground.primary)
                    .lineLimit(1)
                Text(node.detail)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Design.Foreground.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(width: WorkspaceGraphSnapshot.nodeWidth, height: WorkspaceGraphSnapshot.nodeHeight)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Design.Background.raised)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    node.orphaned ? Design.Tint.warning.opacity(0.8) : Design.Border.hairline,
                    lineWidth: node.orphaned ? 1 : 0.5
                )
        }
    }
}

private struct WorkspaceGraphSnapshot {
    static let nodeWidth: CGFloat = 184
    static let nodeHeight: CGFloat = 58
    private static let horizontalSpacing: CGFloat = 232
    private static let verticalSpacing: CGFloat = 82
    private static let margin: CGFloat = 64

    struct Node: Identifiable {
        let ref: Reference
        let position: CGPoint
        let detail: String
        let orphaned: Bool
        var id: Reference { ref }
    }

    struct Edge {
        let source: Reference
        let target: Reference
        let route: Bool
    }

    let nodes: [Node]
    let edges: [Edge]
    let positions: [Reference: CGPoint]
    let size: CGSize

    init() {
        let workspaceRefs = Runtime.shared.workspaces.sorted(by: Self.sort)
        let spaces = Dictionary(uniqueKeysWithValues: Runtime.shared.all(as: Space.self))
        var positions: [Reference: CGPoint] = [:]
        var orphaned: Set<Reference> = []
        var visited: Set<Reference> = []
        var cursorY = Self.margin + Self.nodeHeight / 2
        var maximumDepth = 0

        func place(_ ref: Reference, depth: Int) -> CGFloat {
            if let position = positions[ref] { return position.y }
            guard visited.insert(ref).inserted, let space = spaces[ref] else {
                let y = cursorY
                cursorY += Self.verticalSpacing
                return y
            }

            maximumDepth = max(maximumDepth, depth)
            let children = space.spaces.filter { spaces[$0] != nil }.sorted(by: Self.sort)
            let childYs = children.map { place($0, depth: depth + 1) }
            let y: CGFloat
            if let first = childYs.first, let last = childYs.last { y = (first + last) / 2 }
            else {
                y = cursorY
                cursorY += Self.verticalSpacing
            }
            positions[ref] = CGPoint(
                x: Self.margin + Self.nodeWidth / 2 + CGFloat(depth) * Self.horizontalSpacing,
                y: y
            )
            return y
        }

        for workspace in workspaceRefs {
            let roots = Workspace.with(workspace, { $0.spaces })?.filter { spaces[$0] != nil }.sorted(by: Self.sort) ?? []
            let rootYs = roots.map { place($0, depth: 1) }
            let y: CGFloat
            if let first = rootYs.first, let last = rootYs.last { y = (first + last) / 2 }
            else {
                y = cursorY
                cursorY += Self.verticalSpacing
            }
            positions[workspace] = CGPoint(x: Self.margin + Self.nodeWidth / 2, y: y)
            cursorY += Self.verticalSpacing / 2
        }

        for ref in spaces.keys.filter({ !visited.contains($0) }).sorted(by: Self.sort) {
            orphaned.insert(ref)
            _ = place(ref, depth: 0)
        }

        var edges: [Edge] = []
        for workspace in workspaceRefs {
            for child in Workspace.with(workspace, { $0.spaces }) ?? [] where positions[child] != nil {
                edges.append(.init(source: workspace, target: child, route: false))
            }
        }
        for (ref, space) in spaces {
            for child in space.spaces where positions[child] != nil {
                edges.append(.init(source: ref, target: child, route: false))
            }
        }

        for (_, route) in Runtime.shared.all(as: Route.self).sorted(by: { Self.sort($0.0, $1.0) }) {
            guard let source = route.origin,
                  let target = route.target,
                  positions[source] != nil,
                  positions[target] != nil
            else { continue }
            edges.append(.init(source: source, target: target, route: true))
        }

        self.positions = positions
        self.edges = edges
        self.nodes = positions.map { ref, position in
            let detail: String
            if let workspace = Workspace.with(ref, { $0 }) {
                detail = "\(ref.descriptor.framing.rawValue.capitalized) · \(workspace.spaces.count) root spaces"
            } else if let space = spaces[ref] {
                detail = orphaned.contains(ref)
                    ? "Unattached space"
                    : "\(space.spaces.count) children · \(space.routes.count) routes"
            } else {
                detail = "Structure"
            }
            return Node(ref: ref, position: position, detail: detail, orphaned: orphaned.contains(ref))
        }.sorted { lhs, rhs in
            if lhs.position.y == rhs.position.y { return lhs.position.x < rhs.position.x }
            return lhs.position.y < rhs.position.y
        }
        self.size = CGSize(
            width: Self.margin * 2 + Self.nodeWidth + CGFloat(maximumDepth) * Self.horizontalSpacing,
            height: max(cursorY + Self.margin, 320)
        )
    }

    private static func sort(_ lhs: Reference, _ rhs: Reference) -> Bool {
        let order = lhs.descriptor.name.localizedCaseInsensitiveCompare(rhs.descriptor.name)
        return order == .orderedSame ? lhs.id.uuidString < rhs.id.uuidString : order == .orderedAscending
    }
}
