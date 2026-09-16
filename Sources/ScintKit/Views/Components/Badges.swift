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

struct StateBadge: View {
    let composition: Composition?

    private var appearance: (label: String, symbol: String, tint: Color) {
        switch composition?.state {
            case .inactive: ("Inactive", "sleep", Style.Foreground.muted)
            case .active: ("Active", "timer.square", Style.Tint.Intent.observe)
            case .working: ("Working", "figure.walk.diamond", Style.Tint.material)
            case .completed: ("Completed", "checkmark.seal", Style.Tint.Intent.search)
            case .failed: ("Failed", "exclamationmark.octagon", Style.Tint.alert)
            case nil: ("Unavailable", "minus", Style.Foreground.muted)
        }
    }

    var body: some View {
        let appearance = appearance
        Image(systemName: appearance.symbol)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(appearance.tint)
            .frame(width: 26, height: 26)
            .background(appearance.tint.opacity(0.3), in: Circle())
            .accessibilityLabel("Composition state: \(appearance.label)")
            .help(appearance.label)
    }
}

struct Badges: View {
    let model: any Model
    var ref: Reference? = nil

    var counts: ComponentCount {
        var counts = ComponentCount()
        var materials: [Reference] = []
        let scoped = ref == nil ? model.session.opened.material : nil

        if let scoped {
            materials = [scoped]
        } else if let structure = ref ?? model.session.selection.structure, let space = Space.with(structure, { $0 }) {
            counts.spaces = space.spaces.count
            counts.artifacts = space.artifacts.count
            counts.commands = space.commands.count
            materials = space.materials
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
                label: "\(counts.completedTasks)/\(counts.totalTasks)",
                image: "checkmark.app",
                tint: Style.Tint.task,
                active: counts.totalTasks > 0
            )
            Divider().padding(.vertical, 8)
            Badge(
                label: "\(counts.commands)",
                image: "switch.2",
                tint: Style.Tint.command,
                active: counts.commands > 0
            )
            Divider().padding(.vertical, 8)
            Badge(
                label: "\(counts.artifacts)",
                image: "archivebox",
                tint: Style.Tint.artifact,
                active: counts.artifacts > 0
            )
            Spacer()
            if let ref { StateBadge(composition: model.compose(ref)) }
        }
        .frame(maxHeight: 30)
    }
}
