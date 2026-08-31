import SwiftUI


struct BadgeButton: View {
    var label: String
    var image: String
    var tint: Color = Style.Tint.space
    var active: Bool = true

    var body: some View {
        Button { } label: {
            HStack(alignment: .center) {
                Image(systemName: image)
                    .font(.system(size: 13))
                    .foregroundStyle(active ? tint : Style.Foreground.faint)

                Text(label)
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(active ? Style.Foreground.base : Style.Foreground.faint)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: false, vertical: true)
            .opacity(active ? 1.0 : 0.8)
        }
        .buttonStyle(.borderless)
    }
}

struct BadgeBar: View {
    let model: any Model

    private struct Counts {
        var spaces = 0
        var artifacts = 0
        var commands = 0
        var materials = 0
        var completedTasks = 0
        var totalTasks = 0
    }

    private var origin: Reference { model.session.origin }

    private var counts: Counts {
        var counts = Counts()
        var materials: [Reference] = []

        if let space = Space.with(origin, { $0 }) {
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
        counts.materials = materials.count

        for ref in materials {
            Material.with(ref) { material in
                for block in material.blocks {
                    switch block {
                        case .artifact: counts.artifacts += 1
                        case .command: counts.commands += 1
                        case .task(_, _, let completed):
                            counts.totalTasks += 1
                            if completed { counts.completedTasks += 1 }
                        case .material, .text: break
                    }
                }
            }
        }

        return counts
    }

    var body: some View {
        let counts = counts

        HStack(alignment: .center) {
            BadgeButton(
                label: "\(counts.spaces)",
                image: "app",
                tint: Style.Tint.space,
                active: counts.spaces > 0
            )
            Divider().padding(.vertical, 8)
            BadgeButton(
                label: "\(counts.materials)",
                image: "text.alignleft",
                tint: Style.Tint.material,
                active: counts.materials > 0
            )
            Divider().padding(.vertical, 8)
            BadgeButton(
                label: "\(counts.completedTasks)/\(counts.totalTasks)",
                image: "checkmark.app",
                tint: Style.Tint.task,
                active: counts.totalTasks > 0
            )
        }
        .frame(maxHeight: 30)
    }
}
