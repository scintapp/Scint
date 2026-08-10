import SwiftUI


enum TranscriptContent {
    case message(String)
    case reasoning(String)
    case tool(name: String, verb: String)

    init?(_ value: Value) {
        let content = value.rendered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, content != "Reading additional input from stdin..." else { return nil }
        guard let properties = Properties.load(content) else { self = .message(content); return }
        guard properties["type"]?.string?.lowercased() == "item.completed" else { return nil }

        switch properties["item.type"]?.string?.lowercased() {
            case "agent_message", "message":
                guard let text = properties["item.text"]?.string, !text.isEmpty else { return nil }
                self = .message(text)

            case "reasoning":
                guard let text = properties["item.text"]?.string, !text.isEmpty else { return nil }
                self = .reasoning(text)

            case "command_execution", "command":
                guard let command = properties["item.command"]?.string, !command.isEmpty else { return nil }
                self = .tool(name: command, verb: "Ran")

            case "mcp_tool_call":
                let server = properties["item.server"]?.string ?? ""
                let tool = properties["item.tool"]?.string ?? "tool"
                self = .tool(name: server.isEmpty ? tool : "\(server).\(tool)", verb: "Called")

            case "function_call", "function":
                let name = properties["item.name"]?.string ?? "function"
                self = .tool(name: name, verb: "Called")

            default:
                return nil
        }
    }

    var isTool: Bool {
        if case .tool = self { return true }
        return false
    }
}

enum TranscriptState {
    case running
    case completed
    case failed

    init(_ transcript: Transcript) {
        guard let last = transcript.entries.last, last.terminal else { self = .running; return }
        if case .event(_, .failed(_), _) = last { self = .failed }
        else { self = .completed }
    }

    var title: String {
        switch self {
            case .running: "Running"
            case .completed: "Completed"
            case .failed: "Failed"
        }
    }

    var tint: Color {
        switch self {
            case .running: Design.Tint.working
            case .completed: Design.Tint.active
            case .failed: Design.Tint.failed
        }
    }

    var symbol: String {
        switch self {
            case .running: "circle.dotted"
            case .completed: "checkmark.rectangle.stack.fill"
            case .failed: "exclamationmark.triangle.fill"
        }
    }
}

private extension Transcript.Entry {
    var branch: Reference? {
        guard case .transcript(let ref, _) = self else { return nil }
        return ref
    }

    var isInput: Bool {
        switch self {
            case .value(let key, _, _): key == "prompt"
            case .scene(let ref, _): ref.descriptor.tags.contains("input")
            default: false
        }
    }

    var isOutput: Bool {
        guard case .value(let key, _, _) = self else { return false }
        return key != "prompt"
    }

    var isAction: Bool {
        guard case .event(_, .updated(let value), _) = self else { return false }
        return TranscriptContent(value)?.isTool == true
    }
}

struct TranscriptRunHeader: View {
    let name: String
    let state: TranscriptState
    let created: Date?
    let duration: String?
    let expanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .frame(width: 12)

                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(state.tint)

                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Design.Foreground.secondary)
                    .lineLimit(1)

                if let created { Text(created, style: .time) }
                if let duration { Text(duration) }

                Spacer(minLength: 0)
            }
            .font(Typography.body)
            .foregroundStyle(Design.Foreground.tertiary)
            .frame(height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: expanded)
    }
}

struct TranscriptInput: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(text)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Design.Foreground.primary)
                .lineSpacing(Spacing.lineSpacingBody)
                .frame(maxWidth: 640, alignment: .leading)
                .padding(.leading, 4)
        }
        .padding(12)
        .background(Design.Shape.bubble.fill(Design.Border.cardBorder.opacity(0.33)))
        .overlay(Design.Shape.bubble.strokeBorder(Design.Border.controlBorder, lineWidth: 0.45))
    }
}

struct TranscriptMessage: View {
    let content: String
    var failed = false

    var body: some View {
        let text = (try? AttributedString(markdown: content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(content)

        return Text(text)
            .font(.system(size: 14))
            .foregroundStyle(failed ? Design.Foreground.secondary : Design.Foreground.primary)
            .lineSpacing(Spacing.lineSpacingMessage)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
    }
}

struct TranscriptOutput: View {
    let value: Value
    var failed = false

    var body: some View {
        if let content = TranscriptContent(value) {
            switch content {
                case .message(let text):
                    TranscriptMessage(content: text, failed: failed)

                case .reasoning(let text):
                    TranscriptReasoning(content: text)

                case .tool(name: let name, verb: let verb):
                    TranscriptToolCall(verb: verb, name: name)
            }
        }
    }
}

struct TranscriptReasoning: View {
    let content: String

    var body: some View {
        Text(content)
            .font(.system(size: 13).italic())
            .foregroundStyle(Design.Foreground.tertiary)
            .lineSpacing(Spacing.lineSpacingBody)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Design.Shape.block.fill(Design.Background.block.opacity(0.34)))
    }
}

struct TranscriptToolCall: View {
    let verb: String
    let name: String

    private let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "switch.2")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Design.Tint.command)
                .frame(width: 22, height: 22)
                .background(shape.fill(Design.Tint.command.opacity(0.10)))

            Text(verb)
                .font(Typography.label)
                .foregroundStyle(Design.Foreground.tertiary)

            Text(name)
                .font(Typography.monoSmall)
                .foregroundStyle(Design.Foreground.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
        .frame(height: 30)
    }
}

struct TranscriptOutputRow: View {
    let name: String
    let detail: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "doc.badge.checkmark")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Design.Tint.artifact)

            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Design.Foreground.primary)
                .lineLimit(1)

            Text(detail)
                .font(Typography.monoSmall)
                .foregroundStyle(Design.Foreground.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
    }
}

struct TranscriptScene: View {
    let ref: Reference

    var body: some View {
        if ref.descriptor.tags.contains("input"),
           let content = Scene.with(ref, { scene in
               var input = scene
               if !input.blocks.isEmpty { input.delete(at: input.blocks.index(before: input.blocks.endIndex)) }
               return input.rendered.trimmingCharacters(in: .whitespacesAndNewlines)
           }), !content.isEmpty {

            TranscriptInput(text: content)
        }
    }
}

struct TranscriptSummary: View {
    let state: TranscriptState
    let actions: Int
    let duration: String?
    let outputs: [Transcript.Entry]

    private var detail: String {
        var parts = [actions == 1 ? "1 action" : "\(actions) actions"]
        if let duration { parts.append(duration) }
        return parts.joined(separator: "  ·  ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: state.symbol)
                    .font(.system(size: 13))
                    .foregroundStyle(state.tint)
                    .frame(width: 32, height: 32)
                    .background(Design.Shape.block.fill(state.tint.opacity(0.14)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Design.Foreground.primary)

                    Text(detail)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Design.Foreground.tertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(14)

            if !outputs.isEmpty {
                Rectangle()
                    .fill(Design.Border.controlBorder)
                    .frame(height: 0.45)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(outputs) { entry in
                        if case .value(let key, let value, _) = entry {
                            TranscriptOutputRow(name: key, detail: value.rendered.joined(separator: " "))
                        }
                    }
                }
                .padding(14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.Shape.bubble.fill(Design.Border.cardBorder.opacity(0.33)))
        .overlay(Design.Shape.bubble.strokeBorder(Design.Border.controlBorder, lineWidth: 0.45))
    }
}

struct TranscriptRun: View {
    @State private var expanded = true
    let ref: Reference
    var created: Date? = nil

    private var entries: [Transcript.Entry] { Transcript.with(ref, { $0.entries }) ?? [] }
    private var state: TranscriptState { Transcript.with(ref, { TranscriptState($0) }) ?? .completed }
    private var started: Date? { Transcript.with(ref, { $0.started }).flatMap { $0 } }
    private var stopped: Date? { Transcript.with(ref, { $0.stopped }).flatMap { $0 } }
    private var activity: [Transcript.Entry] { entries.filter { !$0.isInput && !$0.isOutput } }
    private var outputs: [Transcript.Entry] { entries.filter(\.isOutput) }
    private var actions: Int { entries.filter(\.isAction).count }

    private var duration: String? {
        guard let started, let stopped else { return nil }
        let seconds = Int(stopped.timeIntervalSince(started).rounded())
        guard seconds > 0 else { return nil }
        return seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(seconds % 60)s"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.blockSpacing) {
            if let input = entries.first(where: \.isInput) {
                TranscriptEntry(entry: input)
            }

            TranscriptRunHeader(
                name: ref.descriptor.name,
                state: state,
                created: created ?? started,
                duration: duration,
                expanded: expanded,
                onToggle: { expanded.toggle() }
            )

            if expanded {
                VStack(alignment: .leading, spacing: Spacing.messageExtraSpacing) {
                    ForEach(activity) { entry in
                        TranscriptEntry(entry: entry)
                    }
                }
                .padding(.leading, Spacing.quoteInset)
            }

            if state != .running {
                TranscriptSummary(state: state, actions: actions, duration: duration, outputs: outputs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct TranscriptEntry: View {
    let entry: Transcript.Entry

    var body: some View {
        switch entry {
            case .event(_, let signal, _):
                switch signal {
                    case .composed(_), .started(_), .completed(_), .stopped(_):
                        EmptyView()

                    case .updated(let value):
                        TranscriptOutput(value: value)

                    case .failed(let value):
                        TranscriptOutput(value: value, failed: true)
                }

            case .scene(let ref, _):
                TranscriptScene(ref: ref)

            case .transcript(let ref, let created):
                TranscriptRun(ref: ref, created: created)

            case .value(let key, let value, _):
                if key == "prompt" {
                    TranscriptInput(text: value.property.stringRepresentation)
                }
        }
    }
}

struct TranscriptEntries: View {
    let model: any Model
    var transcript: Reference? { model.session.transcript }

    private var entries: [Transcript.Entry] {
        guard let transcript else { return [] }
        return Transcript.with(transcript, { $0.entries }) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if entries.contains(where: { $0.branch != nil }) {
                ForEach(entries) { entry in
                    TranscriptEntry(entry: entry)
                }
            } else if let transcript, !entries.isEmpty {
                TranscriptRun(ref: transcript)
            }
        }
        .frame(maxWidth: 660, alignment: .top)
    }
}
