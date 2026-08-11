import SwiftUI


enum TranscriptContent {
    case message(String)
    case reasoning(String)
    case tool(name: String, verb: String)

    init?(_ value: Value) {
        let content = value.rendered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, content != "Reading additional input from stdin..." else { return nil }
        guard let properties = Properties.load(content)
                else { self = .message(content); return }

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
}

struct TranscriptBlock: View {
    enum Style: Equatable {
        case input
        case message(detail: String? = nil)
        case reasoning
        case tool(verb: String)
    }

    let text: String
    var style: Style = .message()
    var failed = false

    private var markdown: AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }

    var body: some View {
        switch style {
            case .input:
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(Design.Foreground.primary)
                    .lineSpacing(Spacing.lineSpacingBody)
                    .frame(maxWidth: 640, alignment: .leading)
                    .padding(.leading, 4)
                    .padding(12)
                    .background(Design.Shape.bubble.fill(Design.Background.raised))
                    .overlay(Design.Shape.bubble.strokeBorder(Design.Border.cardBorder, lineWidth: 1))
                    .padding(.top, 6)

            case .message(nil):
                Text(markdown)
                    .font(Typography.message)
                    .foregroundStyle(failed ? Design.Foreground.secondary : Design.Foreground.primary)
                    .lineSpacing(Spacing.lineSpacingMessage)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)

            case .message(.some(let detail)):
                VStack(alignment: .leading, spacing: 0) {
                    Text(markdown)
                        .font(.system(size: 13))
                        .foregroundStyle(Design.Foreground.primary)
                        .lineSpacing(Spacing.lineSpacingMessage)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)

                    Rectangle()
                        .fill(Design.Border.cardBorder)
                        .frame(height: 1)

                    HStack(spacing: 9) {
                        Image(systemName: "checkmark.rectangle.stack.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Design.Foreground.accent)

                        Text(detail)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Design.Tint.working)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                }
                .background(Design.Shape.node.fill(Design.Background.raised))
                .overlay(Design.Shape.node.strokeBorder(Design.Border.cardBorder, lineWidth: 1))
                .padding(.vertical, 6)

            case .reasoning:
                Text(text)
                    .font(.system(size: 12).italic())
                    .foregroundStyle(Design.Foreground.tertiary)
                    .lineSpacing(Spacing.lineSpacingBody)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                    .padding(.vertical, 4)

            case .tool(let verb):
                HStack(spacing: 10) {
                    Image(systemName: "switch.2")
                        .font(.system(size: 13))
                        .foregroundStyle(Design.Foreground.secondary)
                        .frame(maxWidth: 26, maxHeight: 26)

                    Text("\(verb) \(text)")
                        .font(.system(size: 12))
                        .foregroundStyle(Design.Foreground.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 0)
                }
                .frame(height: 30)
                .padding(.leading, 12)
        }
    }
}

struct TranscriptHeader: View {
    let name: String
    let created: Date?
    let duration: String?
    let collapsed: Bool
    let onToggle: () -> Void
    var raw: Bool = false
    var onRaw: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(collapsed ? 0 : 90))
                        .frame(width: 14)

                    Text(name)
                        .foregroundStyle(Design.Foreground.secondary)
                        .lineLimit(1)

                    if let created { Text(created, style: .time) }
                    if let duration { Text(duration) }

                    Rectangle()
                        .fill(Design.Border.cardBorder)
                        .frame(height: 0.5)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let onRaw {
                Button(action: onRaw) {
                    Image(systemName: raw ? "curlybraces.square.fill" : "curlybraces.square")
                        .font(.system(size: 12))
                        .foregroundStyle(raw ? Design.Foreground.secondary : Design.Foreground.tertiary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(raw ? "Show rendered transcript" : "Show raw signals")
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Design.Foreground.tertiary)
        .frame(height: 24)
        .animation(.easeOut(duration: 0.12), value: collapsed)
    }
}

struct TranscriptRaw: View {
    let entries: [Transcript.Entry]

    private func line(_ entry: Transcript.Entry) -> (kind: String, text: String) {
        switch entry {
            case .event(_, let signal, _):
                switch signal {
                    case .composed(let ref): return ("composed", ref.descriptor.name)
                    case .started(let ref): return ("started", ref.descriptor.name)
                    case .stopped(let ref): return ("stopped", ref.descriptor.name)
                    case .updated(let value): return ("updated", value.rendered.joined(separator: "\n"))
                    case .completed(let value): return ("completed", value?.rendered.joined(separator: "\n") ?? "")
                    case .failed(let value): return ("failed", value.rendered.joined(separator: "\n"))
                }
            case .material(let ref, _): return ("material", ref.descriptor.name)
            case .value(let key, let value, _): return (key, value.rendered.joined(separator: "\n"))
            case .transcript(let ref, _): return ("transcript", ref.descriptor.name)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(entries) { entry in
                let line = line(entry)

                HStack(alignment: .top, spacing: 8) {
                    Text(entry.created, format: .dateTime.hour().minute().second())
                        .foregroundStyle(Design.Foreground.quaternary)

                    Text(line.kind)
                        .foregroundStyle(Design.Foreground.tertiary)
                        .frame(width: 76, alignment: .leading)

                    Text(line.text)
                        .foregroundStyle(Design.Foreground.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TranscriptEntry: View {
    let entry: Transcript.Entry
    var detail: String? = nil

    @ViewBuilder private func output(_ value: Value, failed: Bool) -> some View {
        switch TranscriptContent(value) {
            case .message(let text): TranscriptBlock(text: text, style: .message(detail: detail), failed: failed)
            case .reasoning(let text): TranscriptBlock(text: text, style: .reasoning)
            case .tool(let name, let verb): TranscriptBlock(text: name, style: .tool(verb: verb))
            case nil: EmptyView()
        }
    }

    // The input material drops its trailing block — that is the composer's live edit,
    // not part of what was sent.
    private func input(_ ref: Reference) -> String? {
        guard ref.descriptor.tags.contains("input") else { return nil }
        let content = Material.with(ref) { material in
            var input = material
            if !input.blocks.isEmpty { input.delete(at: input.blocks.index(before: input.blocks.endIndex)) }
            return input.rendered.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let content, !content.isEmpty else { return nil }
        return content
    }

    var body: some View {
        switch entry {
            case .event(_, let signal, _):
                switch signal {
                    case .composed, .started, .completed, .stopped: EmptyView()
                    case .updated(let value): output(value, failed: false)
                    case .failed(let value): output(value, failed: true)
                }

            case .material(let ref, _):
                if let text = input(ref) { TranscriptBlock(text: text, style: .input) }

            case .transcript(let ref, let created):
                TranscriptView(ref: ref, created: created)

            case .value(let key, let value, _):
                if key == "prompt" {
                    TranscriptBlock(text: value.property.stringRepresentation, style: .input)
                }
        }
    }
}

struct TranscriptEntries: View {
    let model: any Model

    private var transcript: Reference? {
        model.session.origin.context?.transcript ?? model.session.transcript
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let transcript, let entries = Transcript.with(transcript, { $0.entries }) {
                ForEach(entries) { entry in
                    TranscriptEntry(entry: entry)
                }
            }
        }
        .frame(maxWidth: 660, alignment: .top)
    }
}

struct TranscriptView: View {
    @State private var collapsed = false
    @State private var raw = false

    let ref: Reference
    var created: Date? = nil

    var body: some View {
        if let transcript = Transcript.with(ref, { $0 }) {
            let entries = transcript.entries
            let responses = responses(in: entries)

            // Spacing lives on the entry views, not here — structural events
            // render nothing and would otherwise leave gaps behind.
            VStack(alignment: .leading, spacing: 0) {
                TranscriptHeader(
                    name: ref.descriptor.name,
                    created: created ?? transcript.started,
                    duration: elapsed(from: transcript.started, to: transcript.stopped),
                    collapsed: collapsed,
                    onToggle: { collapsed.toggle() },
                    raw: raw,
                    onRaw: { raw.toggle() }
                )

                if !collapsed {
                    if raw {
                        TranscriptRaw(entries: entries)
                    } else {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            TranscriptEntry(entry: entry, detail: responses[index])
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.vertical, 10)
        }
    }

    // The closing message of each turn — the last agent message before a terminal
    // signal — is blocked out with the turn's tally. Everything still in flight floats.
    private func responses(in entries: [Transcript.Entry]) -> [Int: String] {
        var result: [Int: String] = [:]
        var message: Int?
        var actions = 0
        var opened: Date?

        for (index, entry) in entries.enumerated() {
            switch entry {
                case .value(let key, _, let date) where key == "prompt":
                    message = nil
                    actions = 0
                    opened = date

                case .event(_, let signal, let date):
                    if signal.terminal {
                        if let message { result[message] = tally(actions, from: opened, to: date) }
                        message = nil
                        actions = 0
                        opened = nil
                    } else if case .updated(let value) = signal, let content = TranscriptContent(value) {
                        switch content {
                            case .tool: actions += 1
                            case .message: message = index
                            case .reasoning: break
                        }
                    }

                default:
                    break
            }
        }

        return result
    }

    private func tally(_ actions: Int, from: Date?, to: Date?) -> String {
        var parts = [actions == 1 ? "1 action" : "\(actions) actions"]
        if let duration = elapsed(from: from, to: to) { parts.append(duration) }
        return parts.joined(separator: "  ·  ")
    }

    private func elapsed(from: Date?, to: Date?) -> String? {
        guard let from, let to else { return nil }
        let seconds = Int(to.timeIntervalSince(from).rounded())
        guard seconds > 0 else { return nil }
        return seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(seconds % 60)s"
    }
}
