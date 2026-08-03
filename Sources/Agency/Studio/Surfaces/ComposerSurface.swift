import AgencyRuntime
import SwiftUI


struct TranscriptTicker: View {
    let entries: [Transcript.Entry]
    var title: String? { entries.reversed().compactMap(\.statusTitle).first }


    var body: some View {
        if let title {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Design.Foreground.quaternary)
                Rectangle()
                    .fill(Design.Foreground.quaternary.opacity(0.2))
                    .frame(height: 0.5)
            }
        }
    }
}

private enum TranscriptContent {
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

                case .tool(let verb, let name):
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

struct TranscriptInput: View {
    let ref: Reference

    var body: some View {
        if ref.descriptor.tags.contains("input"),
           let content = Sheet.with(ref, { sheet in
               var input = sheet
               if !input.blocks.isEmpty { input.delete(at: input.blocks.index(before: input.blocks.endIndex)) }
               return input.rendered.trimmingCharacters(in: .whitespacesAndNewlines)
           }), !content.isEmpty {

            HStack {
                Spacer(minLength: 80)
                Text(content)
                    .font(.system(size: 14))
                    .foregroundStyle(Design.Foreground.secondary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Design.Shape.bubble.fill(Design.Background.block.opacity(0.72)))
            }
        }
    }
}

struct TranscriptEntry: View {
    let entry: Transcript.Entry

    var body: some View {
        switch entry {
            case .input(let ref, _):
                TranscriptInput(ref: ref)

            case .transcript:
                EmptyView()

            case .property:
                EmptyView()

            case .signal(let signal, _, _):
                switch signal {
                    case .eval:
                        EmptyView()

                    case .started:
                        EmptyView()

                    case .updated(let value):
                        TranscriptOutput(value: value)

                    case .completed:
                        EmptyView()

                    case .failed(let value):
                        TranscriptOutput(value: value, failed: true)
                }
        }
    }
}

private extension Transcript.Entry {
    var statusTitle: String? {
        switch self {
            case .input:
                return nil
            case .transcript:
                return "Working"
            case .property:
                return nil
            case .signal(let signal, _, _):
                switch signal {
                    case .eval: return "Started"
                    case .started: return "Working"
                    case .updated: return nil
                    case .completed: return "Completed"
                    case .failed: return "Failed"
                }
        }
    }
}

struct TranscriptSurface: Surface {
    var panel: any Panel
    let model: any Model

    var transcript: Transcript? {
        guard
            let active = model.session.active,
            let transcript = Transcript.with(active, { $0 })
        else { return nil }
        return transcript
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if transcript != nil {
                    ForEach(transcript!.entries) { entry in
                        TranscriptEntry(entry: entry)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .textSelection(.enabled)
                    .frame(maxWidth: 660, alignment: .top)
                } else {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
