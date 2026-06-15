import Foundation
import SwiftUI
import AgencyRuntime


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
    enum SheetEntry {
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
        case bookmark(Artifact)
        case command(Command)
        case script(Artifact)
        case skill(Artifact)
        case harness(Harness)
    }

    enum Component {
        static func icon(for ref: Reference) -> String {
            switch ref.type {
            case is Artifact.Type: if let entry = Artifact.with(ref, { $0 })?.kind { return Design.Component.icon(for: entry) }
            case is Command.Type: return "switch.2"
            case is Route.Type: return "app.connected.to.app.below.fill"
            case is Harness.Type: return "gear"
            case is Sheet.Type: for entry in Sheet.with(ref, { $0.entries }) ?? [] { return Design.Component.icon(for: entry) }
            case is Transcript.Type: for entry in Transcript.with(ref, { $0.entries }) ?? [] { return Design.Component.icon(for: entry) }
            case is Space.Type: return "app"
            case is Workspace.Type: return "cube.transparent"
            default: return "app.grid"
            }
            return "app.grid"
        }

        static func icon(for entry: Artifact.Kind) -> String {
            switch entry {
            case .app: return "square.grid.2x2.fill"
            case .file: return "folder"
            case .http: return "doc.badge.ellipsis"
            case .image: return "photo"
            case .script: return "chevron.left.forwardslash.chevron.right"
            case .skill: return "shippingbox"
            case .exec: return "terminal"
            }
        }

        static func icon(for entry: Sheet.Entry) -> String {
            switch entry {
            case .artifact(let ref), .control(let ref), .service(let ref), .sheet(let ref): return Component.icon(for: ref)
            case .content: return "text.alignleft"
            case .task: return "checkmark.app"
            }
        }

        static func icon(for entry: Transcript.Entry) -> String {
            switch entry {
            case .event: return "23.calendar"
            case .sheet(let ref, _): return Self.icon(for: ref)
            case .transcript(let ref, _, _): return Component.icon(for: ref)
            }
        }
    }

    struct Badge {
        let color: Color
        var border: Color { color.opacity(0.17) }
        var background: Color { color.opacity(0.06) }
        var foreground: Color { color.opacity(0.88) }
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

        static var active: Color { Color(red: 0.620, green: 0.590, blue: 0.640) }
        static var observing: Color { Color(red: 0.890, green: 0.9, blue: 1.00) }
        static var running: Color { Color(red: 0.743, green: 0.901, blue: 0.920) }
        static var blocked: Color { Color(red: 0.801, green: 0.630, blue: 0.506) }
        static var failed: Color { Color(red: 0.796, green: 0.555, blue: 0.662) }

        static var ready: Color { Color(red: 0.530, green: 0.720, blue: 0.680) }

        static var info: Color { Color(red: 0.980, green: 1.040, blue: 1.305) }
        static var request: Color { Color(red: 1.090, green: 0.920, blue: 1.120) }
        static var warning: Color { Color(red: 0.89311, green: 0.71807, blue: 0.66035) }
        static var error: Color { Color(red: 0.77637, green: 0.45581, blue: 0.56299) }

        static var success: Color { Color(red: 0.62598, green: 0.74072, blue: 0.90186) }
        static var failure: Color { Color(red: 0.77637, green: 0.45581, blue: 0.56299) }

        static var artifact: Color { Color(red: 0.85884, green: 1.00799, blue: 1.34741) }
        static var control: Color { Color(red: 1.15884, green: 1.00799, blue: 1.44741) }
        static var service: Color { Color(red: 0.743, green: 0.901, blue: 0.920) }
        static var structure: Color { Color(red: 1.27736, green: 1.36706, blue: 1.47239) }
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

struct MessageView: View {
    let text: String
    var body: some View {
        Group {
            if let attributed = try? AttributedString(markdown: text) { Text(attributed) }
            else { Text(text) }
        }
        .font(TranscriptType.message)
        .foregroundStyle(TranscriptTheme.textPrimary)
        .lineSpacing(TranscriptMetric.lineSpacingMessage)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .padding(.horizontal, 8)
    }
}

struct ReasoningView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(TranscriptType.body.italic())
            .foregroundStyle(TranscriptTheme.textQuaternary)
            .lineSpacing(TranscriptMetric.lineSpacingBody)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .padding(.leading, TranscriptMetric.quoteInset)
            .padding(.trailing, TranscriptMetric.quoteInset)
            .overlay(alignment: .leading) {
                Rectangle()
                    .offset(x: 12)
                    .fill(TranscriptTheme.quoteBar)
                    .frame(width: TranscriptMetric.quoteBarWidth)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
            }
    }
}

struct CodeBlock: View {
    let code: String
    var body: some View {
        Text(code)
            .font(TranscriptType.mono)
            .foregroundStyle(TranscriptTheme.textSecondary)
            .lineSpacing(TranscriptMetric.lineSpacingMono)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .glassEffect(.regular, in:
                RoundedRectangle(cornerRadius: TranscriptMetric.blockRadius)
            )
    }
}

struct ActionRow: View {
    let verb: String
    let name: String
    let output: String
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12))
                        .foregroundStyle(TranscriptTheme.provider)
                    Text(verb)
                        .font(TranscriptType.body)
                        .foregroundStyle(TranscriptTheme.textTertiary)
                    Text(name)
                        .font(TranscriptType.monoSmall)
                        .foregroundStyle(TranscriptTheme.textPrimary)
                    Spacer(minLength: 8)
                    if !output.isEmpty {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11))
                            .foregroundStyle(TranscriptTheme.textTertiary)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(output.isEmpty)

            if expanded && !output.isEmpty {
                hairline().padding(.vertical, 7)
                Text(output)
                    .font(TranscriptType.mono)
                    .foregroundStyle(TranscriptTheme.textSecondary)
                    .lineSpacing(TranscriptMetric.lineSpacingMono)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .eventBlock()
    }
}

struct StatusRow: View {
    let lines: [String]
    @State private var expanded = false

    private var earlier: [String] { Array(lines.dropLast()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if expanded {
                ForEach(earlier.indices, id: \.self) { i in
                    statusLine(earlier[i]).opacity(0.85)
                }
            }
            Button {
                guard lines.count > 1 else { return }
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack(spacing: 7) {
                    statusDot
                    Text(lines.last ?? "")
                        .font(TranscriptType.body)
                        .foregroundStyle(TranscriptTheme.textTertiary)
                    if lines.count > 1 {
                        Text("· +\(lines.count - 1) earlier")
                            .font(TranscriptType.body)
                            .foregroundStyle(TranscriptTheme.textTertiary.opacity(0.6))
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(lines.count <= 1)
        }
        .eventBlock()
    }

    private var statusDot: some View {
        Circle().fill(TranscriptTheme.quoteBar).frame(width: 3, height: 3)
    }

    private func statusLine(_ text: String) -> some View {
        HStack(spacing: 7) {
            statusDot
            Text(text).font(TranscriptType.body).foregroundStyle(TranscriptTheme.textTertiary)
            Spacer(minLength: 0)
        }
    }
}

struct DomainRollup: View {
    let label: String
    let events: [String]
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 10, weight: .light))
                        .foregroundStyle(Design.Tint.info)
                    Text(label)
                        .font(TranscriptType.body)
                        .foregroundStyle(TranscriptTheme.textTertiary)
                    Text("· \(events.count) events")
                        .font(TranscriptType.body)
                        .foregroundStyle(TranscriptTheme.textQuaternary)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(TranscriptTheme.textQuaternary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(events.indices, id: \.self) { i in
                        Text(events[i])
                            .font(TranscriptType.body)
                            .foregroundStyle(TranscriptTheme.textTertiary)
                    }
                }
                .padding(.leading, 19)
            }
        }
        .eventBlock()
    }
}

struct StateRow: View {
    let state: Composition.State
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: state.transcriptIcon)
                .font(.system(size: 12))
                .foregroundStyle(Design.Tint.blocked)
            Text(text)
                .font(TranscriptType.body)
                .foregroundStyle(Design.Tint.blocked)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: TranscriptMetric.blockRadius)
                .fill(Design.Tint.blocked.opacity(0.035))
            )
        .overlay(
            RoundedRectangle(cornerRadius: TranscriptMetric.blockRadius)
                .stroke(Design.Tint.blocked.opacity(0.42), lineWidth: 0.5)
        )
    }
}

extension Composition.State {
    var transcriptColor: Color {
        switch self {
        case .failed: return TranscriptTheme.stateFailed
        case .blocked: return TranscriptTheme.stateBlocked
        default: return TranscriptTheme.textTertiary
        }
    }
    var transcriptIcon: String {
        switch self {
        case .failed: return "exclamationmark.triangle"
        case .blocked: return "hand.raised"
        default: return "circle"
        }
    }
}

private extension Event {
    var label: String {
        switch self {
        case .request: return "turn.requested"
        case .composed: return "context.composed"
        case .dispatching: return "dispatch.started"
        case .observing: return "observe.started"
        case .processing: return "process.started"
        case .traversing: return "traverse.started"
        case .progress: return "progress"
        case .completed: return "completed"
        case .blocked: return "blocked"
        case .failed: return "failed"
        case .provider(let properties): return ProviderEvent(properties).text
        }
    }
}

private extension View {
    func eventBlock() -> some View {
        self
            .padding(.vertical, TranscriptMetric.blockPaddingV)
            .padding(.horizontal, TranscriptMetric.blockPaddingH)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TranscriptTheme.surface)
            .clipShape(
                RoundedRectangle(cornerRadius: TranscriptMetric.blockRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: TranscriptMetric.blockRadius, style: .continuous)
                    .stroke(TranscriptTheme.border, lineWidth: 1)
            }
    }

    func hairline(_ height: CGFloat = 0.5) -> some View {
        Rectangle().fill(TranscriptTheme.hairline).frame(height: height)
    }
}
