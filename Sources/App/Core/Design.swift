import AgencyRuntime
import SwiftUI


@MainActor enum Iconography {
    static func icon(for block: Sheet.Block) -> Icon {
        switch block {
            case .artifact(let ref), .command(let ref), .sheet(let ref): return Iconography.icon(for: ref)
            case .content: return Icon(badge: "text.alignleft", tint: Design.Tint.active)
            case .task(_, _, let done): return Icon(badge: done ? "checkmark.app" : "app", tint: Design.Tint.task)
        }
    }

    static func icon(for routine: Harness.Routine) -> Icon {
        switch routine {
            case .dispatch: return Icon(badge: "function", tint: Design.Tint.dispatcher)
            case .observe: return Icon(badge: "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted", tint: Design.Tint.observer)
            case .process: return Icon(badge: "arrow.triangle.2.circlepath", tint: Design.Tint.processor)
            case .traverse: return Icon(badge: "graph.3d", tint: Design.Tint.traverser)
            case .compose: return Icon(badge: "rectangle.3.offgrid", tint: Design.Tint.command)
        }
    }

    static func icon(for entry: Transcript.Entry) -> Icon {
        switch entry {
            case .event: return Icon(badge: "23.calendar", tint: Design.Tint.active)
            case .sheet(let ref, _): return Iconography.icon(for: ref)
            case .transcript(let ref, _, _): return Iconography.icon(for: ref)
        }
    }

    static func icon(for handle: Artifact.Handle) -> Icon {
        switch handle {
            case .app: return Icon(badge: "square.grid.2x2.fill", tint: Design.Tint.artifact)
            case .file: return Icon(badge: "folder", tint: Design.Tint.artifact)
            case .http: return Icon(badge: "doc.badge.ellipsis", tint: Design.Tint.artifact)
            case .image: return Icon(badge: "photo", tint: Design.Tint.artifact)
            case .script: return Icon(badge: "chevron.left.forwardslash.chevron.right", tint: Design.Tint.artifact)
            case .skill: return Icon(badge: "shippingbox", tint: Design.Tint.space)
            case .exec: return Icon(badge: "terminal", tint: Design.Tint.active)
        }
    }

    static func icon(for ref: Reference) -> Icon {
        switch ref.type {
            case is Artifact.Type:
                guard let handle = Artifact.with(ref, { $0 })?.handle
                else { return Icon(badge: "", tint: Design.Tint.active) }
                return Iconography.icon(for: handle)
            case is Space.Type:
                guard let harness = Space.with(ref, { $0.harness }).flatMap({ $0 }),
                      let config = Harness.with(harness, { $0.routine })
                else { return Icon(badge: "app", tint: Design.Tint.success) }
                return Iconography.icon(for: config)
            case is Command.Type:
                return Icon(badge: "switch.2", tint: Design.Tint.command)
            case is Route.Type:
                return Icon(badge: "app.connected.to.app.below.fill", tint: Design.Tint.space)
            case is Harness.Type:
                guard let mode = Harness.with(ref, { $0.routine })
                else { return Icon(badge: "gear", tint: Design.Tint.harness) }
                return Iconography.icon(for: mode)
            case is Sheet.Type:
                return Icon(badge: "text.alignleft", tint: Design.Tint.sheet)
            case is Transcript.Type:
                for entry in Transcript.with(ref, { $0.entries }) ?? [] { return Iconography.icon(for: entry) }
                return Icon(badge: "rectangle.stack", tint: Design.Tint.running)
            case is Workspace.Type:
                return Icon(badge: "cube.transparent", tint: Design.Tint.success)
            default:
                break
        }
        return Icon(badge: "", tint: Design.Tint.active)
    }

    static func symbol(for ref: Reference) -> String {
        icon(for: ref).symbol
    }

    static func symbol(for block: Sheet.Block) -> String {
        icon(for: block).symbol
    }

    static func symbol(for entry: Transcript.Entry) -> String {
        icon(for: entry).symbol
    }

    static func symbol(for handle: Artifact.Handle) -> String {
        icon(for: handle).symbol
    }

    static func symbol(for routine: Harness.Routine) -> String {
        icon(for: routine).symbol
    }

    static func accent(for ref: Reference) -> Color {
        switch ref.type {
            case is Artifact.Type: return Design.Tint.artifact
            case is Command.Type: return Design.Tint.command
            case is Route.Type: return Design.Tint.space
            case is Harness.Type: return Iconography.icon(for: ref).tint
            case is Sheet.Type: return Design.Tint.sheet
            case is Transcript.Type: return Design.Tint.running
            case is Space.Type:
                guard let harness = Space.with(ref, { $0.harness }).flatMap({ $0 }),
                      let mode = Harness.with(harness, { $0.routine })
                else { return Design.Tint.success }
                return Iconography.icon(for: mode).tint
            case is Workspace.Type: return Design.Tint.success
            default: return Iconography.icon(for: ref).tint
        }
    }

    struct Icon: View {
        let badge: String
        let tint: Color
        let symbol: String

        init(badge: String, tint: Color) {
            self.badge = badge
            self.tint = tint
            self.symbol = badge.isEmpty ? "app.grid" : badge
        }

        var body: some View {
            let rectangle = RoundedRectangle(cornerRadius: 6, style: .circular)

            ZStack(alignment: .center) {
                rectangle
                    .fill(tint.opacity(0.2))
                    .stroke(tint.opacity(0.5), lineWidth: 0.75)
                Image(systemName: symbol)
                    .scaleEffect(0.85)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .foregroundStyle(tint)
            }
            .glassEffect(.regular, in: rectangle)
            .frame(width: 17, height: 17, alignment: .center)
        }
    }
}

enum TypeScale {
    static let avatarMonogram: CGFloat = 16
    static let spaceTitle: CGFloat = 14
    static let spaceChevron: CGFloat = 11
    static let sidebarIcon: CGFloat = 15
    static let sidebarText: CGFloat = 13
    static let sidebarAddIcon: CGFloat = 20
    static let pageTitle: CGFloat = 18
    static let sectionTitle: CGFloat = 15
    static let sectionSubtitle: CGFloat = 11
    static let columnHeader: CGFloat = 11
    static let rowTitle: CGFloat = 14
    static let rowMeta: CGFloat = 13
    static let cardTitle: CGFloat = 13
    static let cardMeta: CGFloat = 11
    static let badgeCheck: CGFloat = 10
}

enum LayoutScale {
    static let sidebarHeaderSpacing: CGFloat = 10
    static let sidebarSpaceSpacing: CGFloat = 6
    static let sidebarHeaderHorizontal: CGFloat = 14
    static let sidebarHeaderTop: CGFloat = 14
    static let sidebarHeaderBottom: CGFloat = 8
    static let sidebarListHorizontal: CGFloat = 4
    static let sidebarRowSpacing: CGFloat = 4
    static let sidebarRowVertical: CGFloat = 2
    static let sidebarRowLeading: CGFloat = 0
    static let sidebarRowTrailing: CGFloat = 0
    static let detailStackSpacing: CGFloat = 18
    static let detailTitleTop: CGFloat = 12
    static let detailHorizontal: CGFloat = 20
    static let detailBottom: CGFloat = 20
    static let listStackSpacing: CGFloat = 18
    static let listSectionSpacing: CGFloat = 24
    static let listGroupSpacing: CGFloat = 10
    static let listRowSpacing: CGFloat = 8
    static let listHeaderBottom: CGFloat = 8
    static let listDividerHorizontal: CGFloat = 12
    static let listRowLeadingWidth: CGFloat = 34
    static let listFolderColumn: CGFloat = 180
    static let listUpdatedColumn: CGFloat = 180
    static let listAuthorColumn: CGFloat = 110
    static let listArtworkSpacing: CGFloat = 14
    static let listRowHorizontal: CGFloat = 10
    static let listRowVertical: CGFloat = 8
    static let gridStackSpacing: CGFloat = 22
    static let gridSectionSpacing: CGFloat = 14
    static let gridColumnMin: CGFloat = 180
    static let gridColumnMax: CGFloat = 210
    static let gridColumnSpacing: CGFloat = 22
    static let gridRowSpacing: CGFloat = 22
    static let cardStackSpacing: CGFloat = 8
    static let cardTextSpacing: CGFloat = 4
    static let tagHorizontal: CGFloat = 8
    static let tagVertical: CGFloat = 3
}

enum Design {
    enum SheetGlyph {
        static let background = Design.Background.base
        static let card = Design.Background.panel
        static let cardHeader = Color.primary.opacity(0.06)
        static let stroke = Color.primary.opacity(0.1)
        static let accent = Color.secondary
        static let accentSoft = Color.primary.opacity(0.06)
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color.secondary.opacity(0.7)
        static let codeBlockBg = Color.primary.opacity(0.08)
    }

    enum Library {
        case app(Artifact)
        case bookmark(Artifact)
        case command(Command)
        case harness(Harness)
        case script(Artifact)
        case sheet(SheetGlyph)
        case skill(Artifact)
        case transcript(Transcript)
    }

    @MainActor enum Component {
        static func icon(for ref: Reference) -> String {
            Iconography.symbol(for: ref)
        }

        static func icon(for handle: Artifact.Handle) -> String {
            Iconography.symbol(for: handle)
        }

        static func icon(for routine: Harness.Routine) -> String {
            Iconography.symbol(for: routine)
        }

        static func icon(for entry: Sheet.Block) -> String {
            Iconography.symbol(for: entry)
        }

        static func icon(for entry: Transcript.Entry) -> String {
            Iconography.symbol(for: entry)
        }
    }

    struct Badge {
        let color: Color
        var border: Color { color.opacity(0.17) }
        var background: Color { color.opacity(0.06) }
        var foreground: Color { color.opacity(0.88) }
        var disabledForeground: Color { Color.primary.opacity(0.4) }
        var tableForeground: Color { color.opacity(0.92) }
        var tableGlass: Color { color.opacity(0.14) }
    }

    enum EditorComponent {
        enum Card {
            static let cornerRadius: CGFloat = 18
            static let horizontalPadding: CGFloat = 14
            static let verticalPadding: CGFloat = 12
            static let background = Design.SheetGlyph.card
            static let stroke = Design.SheetGlyph.stroke
        }

        enum LinkCard {
            static let cornerRadius: CGFloat = 12
            static let horizontalPadding: CGFloat = 12
            static let verticalPadding: CGFloat = 8
            static let outerHorizontalPadding: CGFloat = 4
            static let titleFont = Font.system(size: 13, weight: .medium)
            static let previewFont = Font.system(size: 11.5)
            static let selectedBackground = Color.accentColor.opacity(0.16)
            static let hoveredBackground = Color.primary.opacity(0.055)
            static let clearBorder = Color.primary.opacity(0.0)
        }

        enum Badge {
            static let font = Font.system(size: 9.5)
            static let horizontalPadding: CGFloat = 6
            static let verticalPadding: CGFloat = 3
            static let cornerRadius: CGFloat = 6
            static let foreground = Design.SheetGlyph.textTertiary.opacity(0.9)
            static let background = Design.SheetGlyph.textTertiary.opacity(0.07)
            static let stroke = Design.SheetGlyph.textTertiary.opacity(0.16)
        }

        enum StatusPill {
            static let font = Font.system(size: 10.5, weight: .medium)
            static let dotSize: CGFloat = 5
            static let horizontalPadding: CGFloat = 8
            static let verticalPadding: CGFloat = 4
        }

        enum GhostButton {
            static let labelFont = Font.system(size: 10.5, weight: .medium)
            static let iconFont = Font.system(size: 10, weight: .medium)
            static let horizontalPadding: CGFloat = 8
            static let verticalPadding: CGFloat = 4
            static let cornerRadius: CGFloat = 7
        }
    }

    enum Background {
        static var base: Color { Color(red: 0.10375, green: 0.10044, blue: 0.10752) }
        static var block: Color { Color(red: 0.1273, green: 0.12601, blue: 0.1345) }
        static var console: Color { Color(red: 0.09875, green: 0.09875, blue: 0.09875) }
        static var panel: Color { Color(red: 0.09875, green: 0.09875, blue: 0.09875) }
        static var card: Color { Color(red: 0.09875, green: 0.09875, blue: 0.09875) }
        static var editor: Color { Color(red: 0.1373, green: 0.13601, blue: 0.1385) }
    }

    enum Tint {
        static var input: Color { Color(red: 0.780, green: 0.840, blue: 1.205) }
        static var output: Color { Color(red: 1.03119, green: 0.81027, blue: 1.39988) }

        static var dispatcher: Color { Color(red: 1.15884, green: 1.00799, blue: 1.44741) }
        static var observer: Color { Color(red: 0.85884, green: 1.00799, blue: 1.34741) }
        static var processor: Color { Color(red: 1.38884, green: 0.81799, blue: 0.94741) }
        static var traverser: Color { Color(red: 0.943, green: 1.201, blue: 1.220) }

        static var ready: Color { Color(red: 0.530, green: 0.720, blue: 0.680) }
        static var active: Color { Color(red: 0.620, green: 0.590, blue: 0.640) }
        static var running: Color { Color(red: 0.743, green: 0.901, blue: 0.920) }
        static var blocked: Color { Color(red: 0.801, green: 0.630, blue: 0.506) }
        static var failed: Color { Color(red: 0.796, green: 0.555, blue: 0.662) }

        static var info: Color { Color(red: 0.980, green: 1.040, blue: 1.305) }
        static var request: Color { Color(red: 1.090, green: 0.920, blue: 1.120) }
        static var warning: Color { Color(red: 0.89311, green: 0.71807, blue: 0.66035) }
        static var error: Color { Color(red: 0.77637, green: 0.45581, blue: 0.56299) }

        static var success: Color { Color(red: 0.62598, green: 0.74072, blue: 0.90186) }
        static var failure: Color { Color(red: 0.77637, green: 0.45581, blue: 0.56299) }

        static var artifact: Color { Color(red: 0.85884, green: 1.00799, blue: 1.34741) }
        static var command: Color { Color(red: 1.15884, green: 1.00799, blue: 1.44741) }
        static var harness: Color { Color(red: 0.743, green: 0.901, blue: 0.920) }
        static var space: Color { Color(red: 1.27736, green: 1.36706, blue: 1.47239) }
        static var sheet: Color { Color(red: 1.46963, green: 1.08887, blue: 0.98027) }
        static var task: Color { Color(red: 1.38884, green: 0.81799, blue: 0.94741) }
    }
}

enum TranscriptTheme {
    static let base = Color(red: 0.10144, green: 0.10236, blue: 0.10376)
    static let surface = Color(red: 0.12474, green: 0.12521, blue: 0.13072)

    static let textPrimary = Color(red: 0.89455, green: 0.90097, blue: 0.91164)
    static let textSecondary = Color(red: 0.71396, green: 0.73396, blue: 0.72494)
    static let textTertiary = Color(red: 0.53455, green: 0.52297, blue: 0.53164)
    static let textQuaternary = Color(red: 0.40955, green: 0.40097, blue: 0.41364)

    static let border = Color(red: 0.14974, green: 0.14921, blue: 0.15372)
    static let provider = Design.Tint.artifact
    static let stateBlocked = Design.Tint.sheet
    static let stateFailed = Design.Tint.failed

    static let hairline = border.opacity(0.12)
    static let quoteBar = Design.Tint.artifact
}

enum TranscriptType {
    static let message = Font.system(size: 13.5)
    static let body = Font.system(size: 12.5)
    static let label = Font.system(size: 10, weight: .medium)
    static let mono = Font.system(size: 12, design: .monospaced)
    static let monoSmall = Font.system(size: 11, design: .monospaced)
}

enum TranscriptMetric {
    static let blockRadius: CGFloat = 12
    static let blockPaddingV: CGFloat = 10
    static let blockPaddingH: CGFloat = 10
    static let blockSpacing: CGFloat = 12
    static let messageExtraSpacing: CGFloat = 6
    static let quoteBarWidth: CGFloat = 0.5
    static let quoteInset: CGFloat = 22
    static let lineSpacingMessage: CGFloat = 5
    static let lineSpacingBody: CGFloat = 5
    static let lineSpacingMono: CGFloat = 4
}

enum TranscriptItem {
    case message(String)
    case code(String)
    case reasoning(String)
    case action(verb: String, name: String, output: String)
    case status([String])
    case domain(label: String, events: [String])
    case state(Composition.State, String)

    var isMessage: Bool { if case .message = self { return true }; return false }
    var isStatus: Bool  { if case .status  = self { return true }; return false }
    var isReasoning: Bool { if case .reasoning = self { return true }; return false }
}
