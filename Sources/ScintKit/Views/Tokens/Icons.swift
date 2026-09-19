import ScintComponents
import SwiftUI

/// Maps Scint's models onto the design system's icon vocabulary.
@MainActor extension Iconography {
    static func model(for ref: Reference) -> Model {
        switch ref.type {
            case is Artifact.Type: .artifact()
            case is Space.Type: .space(Space.with(ref, { $0 })?.harness.flatMap(intent(of:)))
            case is Harness.Type: .harness(intent(of: ref))
            case is Command.Type: .command()
            case is Bridge.Type: .bridge
            case is Material.Type: .material
            case is Transcript.Type: .transcript
            case is Closure.Type: .closure
            default: .space()
        }
    }

    static func model(for block: Material.Block) -> Model {
        switch block {
            case .artifact(let ref), .command(let ref), .material(let ref): model(for: ref)
            case .text: .text
            case .task(_, _, let done): .task(done: done)
        }
    }

    static func model(for entry: Transcript.Entry) -> Model {
        switch entry {
            case .event: return .event
            case .transcript(let ref, _, _): return model(for: ref)
            case .record(let chunk, _):
                if chunk.origin.type == Command.self || chunk.origin.type == Artifact.self {
                    return model(for: chunk.origin)
                }
                if case .collection(let fields) = chunk.value, case .string("tool")? = fields["type"] {
                    if case .string(let name)? = fields["name"], let op = Op.named(name) { return .tool(op.symbol) }
                    return .tool()
                }
                return .note
        }
    }

    static func icon(for ref: Reference, size: CGFloat = Style.Dimension.icon) -> Icon { Icon(model(for: ref), size: size) }
    static func icon(for block: Material.Block, size: CGFloat = Style.Dimension.icon) -> Icon { Icon(model(for: block), size: size) }
    static func icon(for entry: Transcript.Entry, size: CGFloat = Style.Dimension.icon) -> Icon { Icon(model(for: entry), size: size) }
    static func icon(for intent: ScintRuntimeIntent, size: CGFloat = Style.Dimension.icon) -> Icon { Icon(.harness(iconography(intent)), size: size) }

    static func accent(for ref: Reference) -> Color { model(for: ref).tint.bright }

    /// A space's dot, in its harness's color.
    static func dot(for ref: Reference, size: CGFloat = 13) -> Icon {
        let intent = Space.with(ref, { $0 })?.harness.flatMap(intent(of:))
        return Icon(symbol: "circlebadge.fill", tint: intent?.tint ?? .neutral, size: size)
    }

    static func menuTint(for item: MenuItem) -> Color { menuTints(for: item).bright }

    static func menuTint(for kind: MenuFormKind) -> Color { menuTints(for: kind).bright }

    private static func menuTints(for item: MenuItem) -> Style.Tint {
        if let ref = item.ref { return model(for: ref).tint }
        switch item.commandID {
            case "new-task", "checklist": return .task
            case "new-link", "add-files": return .artifact
            case "heading-1", "heading-2", "heading-3", "quote": return .material
            case "code-block": return .command
            default: return .space
        }
    }

    private static func menuTints(for kind: MenuFormKind) -> Style.Tint {
        switch kind {
            case .task: .task
            case .link, .artifact: .artifact
            case .command: .command
            case .material: .material
        }
    }

    @ViewBuilder static func menuIcon(for item: MenuItem, selected: Bool) -> some View {
        let icon = item.ref.map { icon(for: $0, size: Metrics.rowIcon) }
            ?? item.icon.map { Icon(symbol: $0, tint: menuTints(for: item), size: Metrics.rowIcon) }
        if let icon {
            icon
                .frame(width: Style.Dimension.control(.small), height: Style.Dimension.control(.small))
                .opacity(selected ? 1 : Style.Opacity.pressed)
        }
    }

    private static func intent(of harness: Reference) -> Intent? {
        Harness.with(harness, { iconography($0.intent) })
    }

    private static func iconography(_ intent: ScintRuntimeIntent) -> Intent {
        switch intent {
            case .compose: .compose
            case .dispatch: .dispatch
            case .evaluate: .evaluate
            case .search: .search
        }
    }
}

/// Scint's `Intent`, named so it can be told apart from `Iconography.Intent` inside the extension above.
typealias ScintRuntimeIntent = Intent

extension Iconography.Icon {
    /// Scint's views pass plain colors; a color stands in for both strengths.
    init(symbol: String, tint: Color, sizing: CGFloat = Style.Dimension.icon, selected: Bool = true) {
        self.init(symbol: symbol, tint: Style.Tint(bright: tint, dull: tint), size: sizing, selected: selected)
    }
}
