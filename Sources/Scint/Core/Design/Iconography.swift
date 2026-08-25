import SwiftUI


@MainActor enum Iconography {
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
        private var sizing: CGFloat { custom ? size * 1.2 : size * 1.3 }
        private var radius: CGFloat { size * 0.3 }
        private var padding: CGFloat { custom ? size * 0.1 : 0 }
        private var primary: Color { selected ? Style.Foreground.primary : Style.Foreground.secondary }
        private var secondary: Color { selected ? tint : Style.Foreground.secondary }
        private var background: Color { selected ? tint.opacity(0.28) : tint.opacity(0.14) }

        var body: some View {
            if custom {
                ZStack(alignment: .center) {
                    Image(systemName: "app.fill")
                        .font(.system(size: sizing))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(background)
                        .padding(.top, padding)
                    Image(symbol)
                        .font(.system(size: sizing))
                        .symbolRenderingMode(.monochrome)
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

    struct Glyph: View {
        var active = false
        let size: CGFloat
        let tint: Color

        init(sizing: CGFloat = 14, active: Bool = false) {
            self.size = sizing
            self.tint = .accent
            self.active = active
        }

        private var primary: Color { active ? Style.Foreground.primary : Style.Foreground.secondary }
        private var secondary: Color { active ? tint : Style.Foreground.secondary }
        private var background: Color { active ? tint : tint.opacity(0.66) }

        var body: some View {
            ZStack(alignment: .center) {
                Image(systemName: "cube.fill")
                    .foregroundStyle(background)
                    .font(.system(size: size, weight: .light))
                Image(systemName: "cube.transparent")
                    .foregroundStyle(.secondary)
                    .font(.system(size: size, weight: .light))
                Image(systemName: "cube")
                    .foregroundStyle(primary)
                    .font(.system(size: size, weight: .light))
            }
        }
    }

    enum Model {
        case artifact(Handle)
        case context(Intent)
        case closure
        case command(Parameter)
        case harness(Intent)
        case route
        case material(Block)
        case space
        case transcript(Entry)
        case workspace

        enum Block {
            case artifact
            case command
            case content
            case material
            case task
        }

        indirect enum Parameter {
            case argument(String)
            case content(Reference)
            case interface(Reference)
            case structure(Reference)
            case properties(Properties)
            case requirement(Parameter)
        }

        enum Intent {
            case composer
            case dispatcher
            case executor
            case observer
            case traverser
        }

        enum Entry {
            case signal
            case material
            case transcript
        }

        enum Handle {
            case app
            case bookmark
            case directory
            case executable
            case file
            case image
            case script
            case skill
        }
    }

    enum Custom: String, CaseIterable {
        case inactive = "space.custom"
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

    static func accent(for ref: Reference) -> Color {
        switch ref.type {
            case is Artifact.Type:
                return Style.Tint.artifact
            case is Command.Type:
                return Style.Tint.command
            case is Bridge.Type:
                return Style.Tint.space
            case is Harness.Type:
                return Iconography.icon(for: ref).tint
            case is Material.Type:
                return Style.Tint.material
            case is Transcript.Type:
                return Style.Tint.working
            case is Space.Type:
                guard
                    let harness = Space.with(ref, { $0.harness }).flatMap({ $0 }),
                    let m = Harness.with(harness, { $0.intent })
                else { return Style.Tint.info }
                return Iconography.icon(for: m).tint
            case is Workspace.Type:
                return Style.Tint.info
            default:
                return Iconography.icon(for: ref).tint
        }
    }

    static func icon(for block: Material.Block, size: CGFloat = 14) -> Icon {
        switch block {
            case .artifact(let ref), .command(let ref), .material(let ref): Iconography.icon(for: ref, size: size)
            case .text: Icon(symbol: "line.3.horizontal", tint: Style.Tint.inactive, sizing: size)
            case .task(_, _, let done): Icon(symbol: done ? "checkmark.square" : "square", tint: Style.Tint.task, sizing: size)
        }
    }

    static func icon(for intent: Harness.Intent, size: CGFloat = 14) -> Icon {
        switch intent {
            case .compose: Icon(symbol: "space.custom", tint: Style.Tint.compose, sizing: size)
            case .dispatch: Icon(symbol: "space.custom", tint: Style.Tint.dispatch, sizing: size)
            case .observe: Icon(symbol: "space.custom", tint: Style.Tint.observe, sizing: size)
            case .execute: Icon(symbol: "space.custom", tint: Style.Tint.execute, sizing: size)
            case .traverse: Icon(symbol: "space.custom", tint: Style.Tint.traverse, sizing: size)
        }
    }

    static func icon(for entry: Transcript.Entry, size: CGFloat = 14) -> Icon {
        switch entry {
            case .event: Icon(symbol: "calendar", tint: Style.Tint.active, sizing: size)
            case .material(let ref, _): Iconography.icon(for: ref, size: size)
            case .transcript(let ref, _): Iconography.icon(for: ref, size: size)
            case .value: Icon(symbol: "info.circle", tint: Style.Foreground.tertiary, sizing: size)
        }
    }

    static func icon(for handle: Artifact.Handler, size: CGFloat = 14) -> Icon {
        switch handle {
            case .app: Icon(symbol: "square.grid.2x2.fill", tint: Style.Tint.artifact, sizing: size)
            case .bookmark: Icon(symbol: "bookmark", tint: Style.Tint.artifact, sizing: size)
            case .directory: Icon(symbol: "folder", tint: Style.Tint.artifact, sizing: size)
            case .executable: Icon(symbol: "terminal", tint: Style.Tint.artifact, sizing: size)
            case .file: Icon(symbol: "doc", tint: Style.Tint.artifact, sizing: size)
            case .image: Icon(symbol: "photo", tint: Style.Tint.artifact, sizing: size)
            case .script: Icon(symbol: "scroll", tint: Style.Tint.artifact, sizing: size)
            case .skill: Icon(symbol: "brain.head.profile", tint: Style.Tint.artifact, sizing: size)
        }
    }

    static func icon(for ref: Reference, size: CGFloat = 14) -> Icon {
        switch ref.type {
            case is Artifact.Type:
                guard let artifact = Artifact.with(ref, { $0 })
                else { return Icon(symbol: "archivebox", tint: Style.Tint.active, sizing: size) }
                return Iconography.icon(for: artifact.handler, size: size)

            case is Space.Type:
                guard let space = Space.with(ref, { $0.harness }).flatMap({ $0 }), let harness = Harness.with(space, { $0.intent })
                else { return Icon(symbol: "space.custom", tint: Style.Tint.info, sizing: size) }
                return Iconography.icon(for: harness, size: size)

            case is Command.Type:
                return Icon(symbol: "switch.2", tint: Style.Tint.command, sizing: size)

            case is Bridge.Type:
                return Icon(symbol: "app.connected.to.app.below.fill", tint: Style.Tint.space, sizing: size)

            case is Harness.Type:
                guard let intent = Harness.with(ref, { $0.intent })
                else { return Icon(symbol: "gear", tint: Style.Tint.harness, sizing: size) }
                return Iconography.icon(for: intent, size: size)

            case is Material.Type:
                return Icon(symbol: "text.alignleft", tint: Style.Tint.material, sizing: size)

            case is Transcript.Type:
                return Icon(symbol: "text.bubble", tint: Style.Tint.working, sizing: size)

            case is Workspace.Type:
                return Icon(symbol: "cube.transparent", tint: Style.Tint.info, sizing: size)

            default:
                break
        }
        return Icon(symbol: "space.custom", tint: Style.Tint.active)
    }

    static func model(_ item: Model) -> Icon {
        switch item {
            case .artifact(let handle):
                switch handle {
                    case .app: return Icon(symbol: "square.grid.2x2.fill", tint: Style.Tint.artifact)
                    case .bookmark: return Icon(symbol: "bookmark", tint: Style.Tint.artifact)
                    case .directory: return Icon(symbol: "folder", tint: Style.Tint.artifact)
                    case .executable: return Icon(symbol: "terminal", tint: Style.Tint.artifact)
                    case .file: return Icon(symbol: "doc", tint: Style.Tint.artifact)
                    case .image: return Icon(symbol: "photo", tint: Style.Tint.artifact)
                    case .script: return Icon(symbol: "scroll", tint: Style.Tint.artifact)
                    case .skill: return Icon(symbol: "brain.head.profile", tint: Style.Tint.artifact)
                }

            case .context(let intent):
                switch intent {
                    case .composer: return Iconography.model(.harness(.composer))
                    case .dispatcher: return Iconography.model(.harness(.dispatcher))
                    case .executor: return Iconography.model(.harness(.executor))
                    case .observer: return Iconography.model(.harness(.observer))
                    case .traverser: return Iconography.model(.harness(.traverser))
                }

            case .closure:
                return Icon(symbol: "rectangle.stack", tint: Style.Tint.info)

            case .command(let parameter):
                switch parameter {
                    case .argument: return Icon(symbol: "textformat", tint: Style.Tint.command)
                    case .content(let ref), .interface(let ref), .structure(let ref): return icon(for: ref)
                    case .properties: return Icon(symbol: "slider.horizontal.3", tint: Style.Tint.command)
                    case .requirement: return Icon(symbol: "asterisk", tint: Style.Tint.request)
                }

            case .harness(let intent):
                switch intent {
                    case .composer: return Icon(symbol: "space.badge.ellipsis", tint: Style.Tint.compose)
                    case .dispatcher: return Icon(symbol: "space.badge.play", tint: Style.Tint.dispatch)
                    case .executor: return Icon(symbol: "space.badge.sparkles", tint: Style.Tint.execute)
                    case .observer: return Icon(symbol: "space.badge.eye", tint: Style.Tint.observe)
                    case .traverser: return Icon(symbol: "space.badge.magnifyingglass", tint: Style.Tint.traverse)
                }

            case .route:
                return Icon(symbol: "app.connected.to.app.below.fill", tint: Style.Tint.space)

            case .material(let block):
                switch block {
                    case .artifact: return Iconography.model(.artifact(.file))
                    case .command: return Icon(symbol: "switch.2", tint: Style.Tint.command)
                    case .content: return Icon(symbol: "text.alignleft", tint: Style.Tint.material)
                    case .material: return Icon(symbol: "text.alignleft", tint: Style.Tint.material)
                    case .task: return Icon(symbol: "app", tint: Style.Tint.task)
                }

            case .space:
                return Icon(symbol: "space.custom", tint: Style.Tint.space)

            case .transcript(let entry):
                switch entry {
                    case .signal: return Icon(symbol: "calendar", tint: Style.Tint.active)
                    case .material: return Icon(symbol: "text.alignleft", tint: Style.Tint.material)
                    case .transcript: return Icon(symbol: "rectangle.stack", tint: Style.Tint.working)
                }

            case .workspace:
                return Icon(symbol: "cube.transparent", tint: Style.Tint.workspace)
        }
    }

    static func symbol(for ref: Reference) -> String { icon(for: ref).symbol }
    static func symbol(for block: Material.Block) -> String { icon(for: block).symbol }
    static func symbol(for entry: Transcript.Entry) -> String { icon(for: entry).symbol }
    static func symbol(for handle: Artifact.Handler) -> String { icon(for: handle).symbol }
    static func symbol(for intent: Harness.Intent) -> String { icon(for: intent).symbol }
}
