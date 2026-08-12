import Foundation


/// Harness output, classified once. The transcript view and the serialization both
/// read through this so the screen and the process see the same thing.
enum TranscriptContent {
    case message(String)
    case reasoning(String)
    case tool(name: String, verb: String)

    init?(_ value: Value) {
        let content = value.rendered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, content != "Reading additional input from stdin..." else { return nil }
        guard let properties = Properties.load(content)
                else { self = .message(content); return }

        let kind = properties["type"]?.string?.lowercased()

        // Claude Code streams envelopes rather than completed items.
        if let kind, Self.claudeEnvelopes.contains(kind) {
            guard let content = Self.claude(properties, kind: kind) else { return nil }
            self = content
            return
        }

        guard kind == "item.completed" else { return nil }

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

    private static let claudeEnvelopes: Set<String> = [
        "assistant", "user", "result", "system", "rate_limit_event"
    ]

    /// Only assistant turns carry content worth showing: `system` and `rate_limit_event`
    /// are setup noise, `user` echoes tool results already shown as the call, and
    /// `result` repeats the final assistant text verbatim.
    private static func claude(_ properties: Properties, kind: String) -> TranscriptContent? {
        guard kind == "assistant", let blocks = properties["message.content"]?.array else { return nil }

        for block in blocks {
            guard let block = block.properties else { continue }
            switch block["type"]?.string?.lowercased() {
                case "text":
                    guard let text = block["text"]?.string,
                          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                    return .message(text)

                case "thinking":
                    guard let text = block["thinking"]?.string,
                          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                    return .reasoning(text)

                case "tool_use":
                    return .tool(name: block["name"]?.string ?? "tool", verb: "Called")

                default:
                    continue
            }
        }
        return nil
    }
}
