import SwiftUI


struct ComponentCount: Sendable {
    var notes = 0
    var spaces = 0
    var artifacts = 0
    var commands = 0
    var materials = 0
    var completedTasks = 0
    var totalTasks = 0

    mutating func include(_ blocks: [Material.Block], countMaterials: Bool = true) {
        for (index, block) in blocks.enumerated() {
            switch block {
                case .artifact: artifacts += 1
                case .command: commands += 1
                case .material: if countMaterials { materials += 1 }
                case .task(_, _, let completed):
                    totalTasks += 1
                    if completed { completedTasks += 1 }
                case .text(_, let text):
                    let source = text as NSString
                    let prose = NSMutableString(string: text)
                    for link in Markdown.scan(text).links.reversed() {
                        guard let ref = Reference.Link.reference(in: source.substring(with: link.url)) else { continue }
                        prose.replaceCharacters(in: link.range, with: "")
                        switch ref.type {
                            case is Artifact.Type: artifacts += 1
                            case is Command.Type: commands += 1
                            case is Material.Type: if countMaterials { materials += 1 }
                            default: break
                        }
                    }
                    if !(index == 0 && text.hasPrefix("# ")),
                       !(prose as String).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { notes += 1 }
            }
        }
    }
}

struct RunningIndicator: View {
    var size: ControlSize = .small

    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .controlSize(size)
            .tint(Style.Tint.space)
    }
}

struct Badge: View {
    var label: String
    var image: String = ""
    var tint: Color = Style.Tint.space
    var active: Bool = true
    var outlined: Bool = false

    var body: some View {
        HStack(spacing: Style.Spacing.sm) {
            if !image.isEmpty {
                Image(systemName: image)
                    .font(Typography.prose)
                    .foregroundStyle(active ? tint : Style.Foreground.faint)
            }

            Text(label)
                .font(outlined ? Typography.badge : Typography.badge.weight(.light))
                .foregroundStyle(active ? outlined ? tint : Style.Foreground.primary : Style.Foreground.faint)
                .lineLimit(Style.Limit.singleLine)
        }
        .padding(.horizontal, outlined ? Style.Spacing.md : .zero)
        .padding(.vertical, outlined ? Style.Spacing.xs : .zero)
        .background {
            if outlined { Style.Shape.capsule.fill(tint.opacity(Style.Opacity.hairline)) }
        }
        .overlay {
            if outlined {
                Style.Shape.capsule.strokeBorder(tint.opacity(Style.Opacity.faint), lineWidth: Style.Dimension.border)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .opacity(active ? Style.Opacity.full : Style.Opacity.strong)
    }
}

struct Badges: View {
    let model: any Model

    var origin: Reference { model.session.origin }

    var counts: ComponentCount {
        var counts = ComponentCount()
        var materials: [Reference] = []
        let scoped = model.session.opened.material

        if let scoped {
            materials = [scoped]
        } else if let space = Space.with(origin, { $0 }) {
            counts.spaces = space.spaces.count
            counts.artifacts = space.artifacts.count
            counts.commands = space.commands.count
            materials = space.materials
        } else if let workspace = Workspace.with(origin, { $0 }) {
            counts.spaces = workspace.spaces.count
            counts.artifacts = workspace.artifacts.count
            counts.commands = workspace.commands.count
            materials = workspace.materials
        }

        materials.removeAll { $0.descriptor.tags.contains("input") }
        if scoped == nil { counts.materials = materials.count }

        for ref in materials {
            Material.with(ref) { material in
                counts.include(material.blocks, countMaterials: scoped != nil)
            }
        }

        return counts
    }

    var body: some View {
        let counts = counts

        HStack(alignment: .center) {
            Badge(
                label: "\(counts.spaces)",
                image: "app",
                tint: Style.Tint.space,
                active: counts.spaces > 0
            )
            Divider().padding(.vertical, 8)
            Badge(
                label: "\(counts.materials)",
                image: "text.alignleft",
                tint: Style.Tint.material,
                active: counts.materials > 0
            )
            Divider().padding(.vertical, 8)
            Badge(
                label: "\(counts.completedTasks)/\(counts.totalTasks)",
                image: "checkmark.app",
                tint: Style.Tint.task,
                active: counts.totalTasks > 0
            )
        }
        .frame(maxHeight: 30)
    }
}
