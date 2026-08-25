import SwiftUI


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
                        .foregroundStyle(Style.Foreground.secondary)
                        .lineLimit(1)

                    if let created { Text(created, style: .time) }
                    if let duration { Text(duration) }

                    Rectangle()
                        .fill(Style.Border.card)
                        .frame(height: 0.5)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let onRaw {
                Button(action: onRaw) {
                    Image(systemName: raw ? "curlybraces.square.fill" : "curlybraces.square")
                        .font(.system(size: 12))
                        .foregroundStyle(raw ? Style.Foreground.secondary : Style.Foreground.tertiary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(raw ? "Show rendered transcript" : "Show raw signals")
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Style.Foreground.tertiary)
        .frame(height: 24)
        .animation(.easeOut(duration: 0.12), value: collapsed)
    }
}

struct TranscriptRaw: View {
    let entries: [Transcript.Entry]

    func line(_ entry: Transcript.Entry) -> (kind: String, text: String) {
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
                        .foregroundStyle(Style.Foreground.quaternary)

                    Text(line.kind)
                        .foregroundStyle(Style.Foreground.tertiary)
                        .frame(width: 76, alignment: .leading)

                    Text(line.text)
                        .foregroundStyle(Style.Foreground.secondary)
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

struct TranscriptBlock: View {
    let text: String
    var type: BlockType = .message()
    var failed = false

    enum BlockType: Equatable {
        case input
        case message(detail: String? = nil)
        case reasoning
        case tool(verb: String)
    }

    var markdown: AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }

    var body: some View {
        switch type {
            case .input:
                HStack(spacing: 0) {
                    Spacer(minLength: 48)

                    Text(text)
                        .font(.system(size: 13))
                        .foregroundStyle(Style.Foreground.primary)
                        .lineSpacing(Style.Spacing.lineSpacingBody)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Style.Shape.bubble.fill(Style.Background.raised))
                        .overlay(Style.Shape.bubble.strokeBorder(Style.Border.card, lineWidth: 1))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 10)
                .padding(.bottom, 4)

            case .message(nil):
                Text(markdown)
                    .font(Typography.message)
                    .foregroundStyle(failed ? Style.Foreground.secondary : Style.Foreground.primary)
                    .lineSpacing(Style.Spacing.lineSpacingMessage)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)

            case .message(.some(let detail)):
                VStack(alignment: .leading, spacing: 8) {
                    Text(markdown)
                        .font(Typography.message)
                        .foregroundStyle(failed ? Style.Foreground.secondary : Style.Foreground.primary)
                        .lineSpacing(Style.Spacing.lineSpacingMessage)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.rectangle.stack.fill")
                            .font(.system(size: 10))
                        Text(detail)
                            .font(.system(size: 11))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Style.Foreground.tertiary)
                }
                .padding(.horizontal, 2)
                .padding(.top, 4)
                .padding(.bottom, 10)

            case .reasoning:
                Text(text)
                    .font(.system(size: 12).italic())
                    .foregroundStyle(Style.Foreground.tertiary)
                    .lineSpacing(Style.Spacing.lineSpacingBody)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                    .padding(.vertical, 4)

            case .tool(let verb):
                HStack(spacing: 10) {
                    Image(systemName: "switch.2")
                        .font(.system(size: 13))
                        .foregroundStyle(Style.Foreground.secondary)
                        .frame(maxWidth: 26, maxHeight: 26)

                    Text("\(verb) \(text)")
                        .font(.system(size: 12))
                        .foregroundStyle(Style.Foreground.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 0)
                }
                .frame(height: 30)
                .padding(.leading, 12)
        }
    }
}

struct TranscriptEntry: View {
    let entry: Transcript.Entry
    var detail: String? = nil

    @ViewBuilder private func output(_ value: Value, failed: Bool) -> some View {
        switch TranscriptContent(value) {
            case .message(let text): TranscriptBlock(text: text, type: .message(detail: detail), failed: failed)
            case .reasoning(let text): TranscriptBlock(text: text, type: .reasoning)
            case .tool(let name, let verb): TranscriptBlock(text: name, type: .tool(verb: verb))
            case nil: EmptyView()
        }
    }

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
                if let text = input(ref) { TranscriptBlock(text: text, type: .input) }

            case .transcript(let ref, let created):
                TranscriptView(ref: ref, created: created)

            case .value(let key, let value, _):
                if key == "input" {
                    TranscriptBlock(text: value.property.stringRepresentation, type: .input)
                }
        }
    }
}

struct TranscriptView: View {
    @State private var collapsed = false
    @State private var raw = false

    let ref: Reference
    var created: Date? = nil

    private func responses(in entries: [Transcript.Entry]) -> [Int: String] {
        var result: [Int: String] = [:]
        var message: Int?
        var actions = 0
        var opened: Date?

        for (index, entry) in entries.enumerated() {
            switch entry {
                case .value(let key, _, let date) where key == "input":
                    message = nil
                    actions = 0
                    opened = date

                case .event(_, let signal, let date):
                    if signal.terminal {
                        if let message, let summary = tally(actions, from: opened, to: date) {
                            result[message] = summary
                        }
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

    private func tally(_ actions: Int, from: Date?, to: Date?) -> String? {
        guard actions > 0 else { return nil }
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

    var body: some View {
        if let transcript = Transcript.with(ref, { $0 }) {
            let entries = transcript.entries
            let responses = responses(in: entries)

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
}

struct TranscriptSurface: Surface {
    var panel: any Panel
    var model: any Model

    var body: some View {
        ScrollView {
            Color.clear.frame(height: 24)

            VStack(alignment: .leading, spacing: 12) {
                if
                    let transcript = model.session.origin.context?.transcript ?? model.session.transcript,
                    let entries = Transcript.with(transcript, { $0.entries }) {
                    ForEach(entries) { entry in TranscriptEntry(entry: entry) }
                }
            }
            .frame(maxWidth: 660, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 12)

            Color.clear.frame(height: 96)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .scrollEdgeEffectStyle(.hard, for: .top)
    }
}

