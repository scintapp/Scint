import AgencyRuntime
import SwiftUI


@MainActor enum Iconography {
    static func icon(for block: Sheet.Block, size: CGFloat = 14) -> Icon {
        switch block {
            case .artifact(let ref), .command(let ref), .sheet(let ref): return Iconography.icon(for: ref, size: size)
            case .content: return Icon(symbol: "text.alignleft", tint: Design.Tint.sheet, sizing: size)
            case .task(_, _, let done): return Icon(symbol: done ? "checkmark.app" : "app", tint: Design.Tint.task, sizing: size)
        }
    }

    static func icon(for routine: Harness.Routine, size: CGFloat = 14) -> Icon {
        switch routine {
            case .compose: return Icon(symbol: "space.badge.ellipsis", tint: Design.Tint.compose, sizing: size)
            case .dispatch: return Icon(symbol: "space.badge.play", tint: Design.Tint.dispatch, sizing: size)
            case .observe: return Icon(symbol: "space.badge.eye", tint: Design.Tint.observe, sizing: size)
            case .execute: return Icon(symbol: "space.badge.sparkles", tint: Design.Tint.execute, sizing: size)
            case .traverse: return Icon(symbol: "space.badge.magnifyingglass", tint: Design.Tint.traverse, sizing: size)
        }
    }

    static func icon(for entry: Transcript.Entry, size: CGFloat = 14) -> Icon {
        switch entry {
            case .event: return Icon(symbol: "calendar", tint: Design.Tint.active, sizing: size)
            case .sheet(let ref, _): return Iconography.icon(for: ref, size: size)
            case .transcript(let ref, _, _): return Iconography.icon(for: ref, size: size)
        }
    }

    static func icon(for handle: Artifact.Handle, size: CGFloat = 14) -> Icon {
        switch handle {
            case .app: return Icon(symbol: "square.grid.2x2.fill", tint: Design.Tint.artifact, sizing: size)
            case .file: return Icon(symbol: "folder", tint: Design.Tint.artifact, sizing: size)
            case .http: return Icon(symbol: "bookmark", tint: Design.Tint.artifact, sizing: size)
            case .image: return Icon(symbol: "photo", tint: Design.Tint.artifact, sizing: size)
            case .script: return Icon(symbol: "scroll", tint: Design.Tint.artifact, sizing: size)
            case .skill: return Icon(symbol: "brain.head.profile", tint: Design.Tint.artifact, sizing: size)
            case .exec: return Icon(symbol: "terminal", tint: Design.Tint.artifact, sizing: size)
        }
    }

    static func icon(for ref: Reference, size: CGFloat = 14) -> Icon {
        switch ref.type {
            case is Artifact.Type:
                guard let handle = Artifact.with(ref, { $0 })?.handle
                else { return Icon(symbol: "", tint: Design.Tint.active, sizing: size) }
                return Iconography.icon(for: handle, size: size)
            case is Space.Type:
                guard let space = Space.with(ref, { $0.harness }).flatMap({ $0 }), let harness = Harness.with(space, { $0.routine })
                else { return Icon(symbol: "space", tint: Design.Tint.info, sizing: size) }
                return Iconography.icon(for: harness, size: size)
            case is Command.Type:
                return Icon(symbol: "switch.2", tint: Design.Tint.command, sizing: size)
            case is Route.Type:
                return Icon(symbol: "app.connected.to.app.below.fill", tint: Design.Tint.space, sizing: size)
            case is Harness.Type:
                guard let routine = Harness.with(ref, { $0.routine })
                else { return Icon(symbol: "gear", tint: Design.Tint.harness, sizing: size) }
                return Iconography.icon(for: routine, size: size)
            case is Sheet.Type:
                return Icon(symbol: "text.alignleft", tint: Design.Tint.sheet, sizing: size)
            case is Transcript.Type:
                for entry in Transcript.with(ref, { $0.entries }) ?? [] { return Iconography.icon(for: entry, size: size) }
                return Icon(symbol: "rectangle.stack", tint: Design.Tint.running, sizing: size)
            case is Workspace.Type:
                return Icon(symbol: "cube.transparent", tint: Design.Tint.info, sizing: size)
            default:
                break
        }
        return Icon(symbol: "space", tint: Design.Tint.active)
    }

    static func symbol(for ref: Reference) -> String { icon(for: ref).symbol }
    static func symbol(for block: Sheet.Block) -> String { icon(for: block).symbol }
    static func symbol(for entry: Transcript.Entry) -> String { icon(for: entry).symbol }
    static func symbol(for handle: Artifact.Handle) -> String { icon(for: handle).symbol }
    static func symbol(for routine: Harness.Routine) -> String { icon(for: routine).symbol }

    static func accent(for ref: Reference) -> Color {
        switch ref.type {
            case is Artifact.Type:
                return Design.Tint.artifact
            case is Command.Type:
                return Design.Tint.command
            case is Route.Type:
                return Design.Tint.space
            case is Harness.Type:
                return Iconography.icon(for: ref).tint
            case is Sheet.Type:
                return Design.Tint.sheet
            case is Transcript.Type:
                return Design.Tint.running
            case is Space.Type:
                guard let harness = Space.with(ref, { $0.harness }).flatMap({ $0 }), let mode = Harness.with(harness, { $0.routine })
                else { return Design.Tint.info }
                return Iconography.icon(for: mode).tint
            case is Workspace.Type:
                return Design.Tint.info
            default:
                return Iconography.icon(for: ref).tint
        }
    }

    enum Custom: String, CaseIterable {
        case inactive = "space"
        case active = "space.badge.sparkles"
        case running = "space.badge.play"
        case request = "space.badge.questionmark"
        case completed = "space.badge.checkmark"
        case blocked = "space.exclamationmark"
        case failed = "space.badge.xmark"
        case compose = "space.badge.ellipsis"
        case dispatch = "space.badge.clock"
        case observe = "space.badge.eye"
        case execute = "space.badge.gearshape"
        case traverse = "space.badge.magnifyingglass"
    }

    struct Icon: View {
        var selected = true
        let symbol: String
        let size: CGFloat
        let tint: Color

        init(symbol: String, tint: Color, sizing: CGFloat = 14, selected: Bool = true) {
            self.symbol = symbol
            self.size = sizing
            self.tint = tint
            self.selected = selected
        }

        private var custom: Bool { Iconography.Custom(rawValue: symbol) != nil }
        private var sizing: CGFloat { custom ? size * 1.2 : size }
        private var radius: CGFloat { size * 0.3 }
        private var padding: CGFloat { custom ? size * 0.1 : 0 }
        private var primary: Color { selected ? tint : Design.Foreground.secondary }
        private var secondary: Color { selected ? Design.Foreground.primary : Design.Foreground.tertiary }
        private var background: Color { selected ? tint.opacity(0.28) : Color.primary.opacity(0.14) }

        private var shape: some View {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(background)
                .frame(maxWidth: size, maxHeight: size, alignment: .center)
        }

        var body: some View {
            if custom {
                ZStack(alignment: .center) {
                    shape
                        .frame(width: size, height: size)
                        .padding(padding)
                        .padding(.bottom, padding)
                    Image(symbol)
                        .font(.system(size: sizing))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(primary, secondary)
                        .padding(.top, padding)
                }
                .frame(width: sizing, height: sizing)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: size))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(primary)
            }
        }
    }
}

