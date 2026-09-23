import SwiftUI
import ScintRuntime
import ScintComponents


struct ComponentCount: Sendable {
    var notes = 0
    var spaces = 0
    var artifacts = 0
    var commands = 0
    var documents = 0
    var completedTasks = 0
    var totalTasks = 0

    mutating func include(_ blocks: [ScintRuntime.Document.Block], countDocuments: Bool = true) {
        for (index, block) in blocks.enumerated() {
            switch block {
                case .artifact: artifacts += 1
                case .command: commands += 1
                case .document: if countDocuments { documents += 1 }
                case .frame(_, let series):
                    include(series, countDocuments: countDocuments)
                case .task(_, _, let completed, _):
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
                            case is ScintRuntime.Document.Type: if countDocuments { documents += 1 }
                            default: break
                        }
                    }
                    if !(index == 0 && text.hasPrefix("# ")),
                       !(prose as String).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { notes += 1 }
            }
        }
    }
}


struct Badge: View {
    var label: String
    var image: String = ""
    var tint: Color = Style.Tint.space.bright
    var active: Bool = true
    var outlined: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if !image.isEmpty {
                Image(systemName: image)
                    .font(Typography.body)
                    .foregroundStyle(active ? tint : Style.Foreground.secondary)
            }

            Text(label)
                .font(outlined ? Typography.detail : Typography.detail.weight(.light))
                .foregroundStyle(active ? outlined ? tint : Style.Foreground.primary : Style.Foreground.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, outlined ? 8 : .zero)
        .padding(.vertical, outlined ? 4 : .zero)
        .background {
            if outlined { Capsule().fill(tint.opacity(Style.Opacity.surface)) }
        }
        .overlay {
            if outlined {
                Capsule().strokeBorder(tint.opacity(Style.Opacity.outline), lineWidth: 1)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .opacity(active ? 1 : Style.Opacity.inactive)
    }
}

struct Badges: View {
    let model: any Model
    var ref: Reference? = nil

    var counts: ComponentCount {
        var counts = ComponentCount()
        var documents: [Reference] = []
        let scoped = ref == nil ? model.session.opened.document : nil

        if let scoped {
            documents = [scoped]
        } else if let structure = ref ?? model.session.selection.structure, let space = Space.with(structure, { $0 }) {
            counts.spaces = space.spaces.count
            counts.artifacts = space.artifacts.count
            counts.commands = space.commands.count
            documents = space.documents
        }

        documents.removeAll { $0.descriptor.tags.contains("input") }
        if scoped == nil { counts.documents = documents.count }

        for ref in documents {
            Document.with(ref) { document in
                counts.include(document.blocks, countDocuments: scoped != nil)
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
                tint: Style.Tint.task.bright,
                active: counts.totalTasks > 0
            )
            Divider().padding(.vertical, 8)
            Badge(
                label: "\(counts.commands)",
                image: "switch.2",
                tint: Style.Tint.command.bright,
                active: counts.commands > 0
            )
            Divider().padding(.vertical, 8)
            Badge(
                label: "\(counts.artifacts)",
                image: "archivebox",
                tint: Style.Tint.artifact.bright,
                active: counts.artifacts > 0
            )
        }
        .frame(maxHeight: 30)
    }
}
