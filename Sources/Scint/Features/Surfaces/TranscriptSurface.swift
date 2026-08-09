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

struct TranscriptMessage: View {
    let content: String
    var failed = false

    var body: some View {
        let text = (try? AttributedString(markdown: content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(content)

        return Text(text)
            .font(.system(size: 14))
            .foregroundStyle(failed ? Design.Foreground.secondary : Design.Foreground.primary)
            .lineSpacing(5)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
    }
}

struct TranscriptReasoning: View {
    let content: String

    var body: some View {
        Text(content)
            .font(.system(size: 13).italic())
            .foregroundStyle(Design.Foreground.tertiary)
            .lineSpacing(4)
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

    var body: some View {
        HStack(spacing: 8) {
            Group {
                Image(systemName: "switch.2")
                Text(verb)
                Text(name)
            }
            .foregroundStyle(Design.Foreground.tertiary)
            .lineLimit(1)
            .truncationMode(.middle)
            .font(.system(size: 12))

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .background(Design.Shape.block.fill(Design.Background.console))
    }
}

struct TranscriptEntry: View {
    let entry: Transcript.Entry

    var body: some View {
        switch entry {
            case .event(_, let signal, _):
                switch signal {
                    case .composed:
                        EmptyView()

                    case .started:
                        EmptyView()

                    case .updated(let value):
                        TranscriptOutput(value: value)

                    case .completed:
                        EmptyView()

                    case .failed(let value):
                        TranscriptOutput(value: value, failed: true)

                    case .stopped:
                        EmptyView()
                }
            case .scene(let ref, _):
                TranscriptScene(ref: ref)

            case .transcript(let ref, let created):
                if let content = Transcript.with(ref, { transcript in
                    VStack(alignment: .leading, spacing: Spacing.blockSpacing) {
                        HStack(spacing: Spacing.messageExtraSpacing) {
                            Text(ref.descriptor.name)
                                .font(Typography.body.weight(.medium))
                                .foregroundStyle(Design.Foreground.primary)
                            Text("—")
                            Text(created, style: .time)
                        }
                        .font(Typography.body)
                        .foregroundStyle(Design.Foreground.tertiary)

                        VStack(alignment: .leading, spacing: Spacing.blockSpacing) {
                            ForEach(transcript.entries) { entry in
                                TranscriptEntry(entry: entry)
                            }
                        }
                        .padding(.leading, Spacing.quoteInset)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }) {
                    content
                }

            case .value:
                EmptyView()


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

            HStack(alignment: .top, spacing: 6) {
                Text(content)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Design.Foreground.primary)
                    .frame(maxWidth: 640, alignment: .leading)
                    .padding(.leading, 4)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Design.Border.cardBorder.opacity(0.33))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Design.Border.controlBorder, lineWidth: 0.45)
            )
        }
    }
}

struct TranscriptEntries: View {
    let model: any Model

    var transcript: Reference? { model.session.transcript }

    var body: some View {
        VStack(spacing: 16) {
            if let transcript, let entries = Transcript.with(transcript, { $0.entries }) {
                ForEach(entries) { entry in
                    TranscriptEntry(entry: entry)
                }
            }
        }
        .frame(maxWidth: 660, alignment: .top)
    }
}
