import Foundation


struct Parser: Codable, Sendable, Equatable {
    var match: [String: String] = [:]
    var each: String? = nil
    var kind: String? = nil
    var fields: [String: String] = [:]

    func matches(_ properties: Properties) -> Bool {
        match.allSatisfy { path, expected in
            properties[path]?.string?.lowercased() == expected.lowercased()
        }
    }

    static func read(_ value: Value, using readings: [Parser] = .vendors) -> [Value] {
        let content = value.rendered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, content != "Parser additional input from stdin..." else { return [] }
        guard let properties = Properties.load(content) else { return [.collection(["type": .string("message"), "text": .string(content)])] }
        return read(properties, using: readings)
    }

    static func read(_ properties: Properties, using readings: [Parser] = .vendors) -> [Value] {
        guard let reading = readings.first(where: { $0.matches(properties) }) else { return [] }

        if let each = reading.each {
            return (properties[each]?.array ?? [])
                .compactMap(\.properties)
                .flatMap { read($0, using: readings) }
        }

        guard let kind = reading.kind else { return [] }

        var resolved: [String: Value] = [:]
        for (name, path) in reading.fields {
            guard let found = properties[path], found.isPresent else { continue }
            if case .string(let text) = found {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                resolved[name] = .string(trimmed)
            } else {
                resolved[name] = converted(found)
            }
        }

        guard !resolved.isEmpty else { return [] }
        resolved["type"] = .string(kind)
        return [.collection(resolved)]
    }

    static func converted(_ property: Property) -> Value {
        switch property {
            case .bool(let value): return .bool(value)
            case .integer(let value): return .integer(value)
            case .decimal(let value): return .decimal(Decimal(value))
            case .string(let value): return .string(value)
            case .array(let values): return .sequence(values.map(converted))
            case .object(let values): return .collection(values.mapValues(converted))
            case .null: return .string("")
        }
    }
}

extension Array where Element == Parser {
    static var vendors: [Parser] { codex + claude }

    static var codex: [Parser] { [
        .init(match: ["type": "item.completed", "item.type": "agent_message"], kind: "message", fields: ["text": "item.text"]),
        .init(match: ["type": "item.completed", "item.type": "message"], kind: "message", fields: ["text": "item.text"]),
        .init(match: ["type": "item.completed", "item.type": "reasoning"], kind: "reasoning", fields: ["text": "item.text"]),
        .init(match: ["type": "item.completed", "item.type": "command_execution"], kind: "tool", fields: ["name": "item.command", "output": "item.aggregated_output", "status": "item.status"]),
        .init(match: ["type": "item.completed", "item.type": "mcp_tool_call"], kind: "tool", fields: ["name": "item.tool", "server": "item.server", "arguments": "item.arguments", "status": "item.status", "result": "item.result", "error": "item.error"]),
        .init(match: ["type": "item.completed", "item.type": "function_call"], kind: "tool", fields: ["name": "item.name", "arguments": "item.arguments"]),
        .init(match: ["type": "item.completed", "item.type": "web_search"], kind: "tool", fields: ["name": "item.query"]),
        .init(match: ["type": "item.completed", "item.type": "error"], kind: "error", fields: ["text": "item.message"]),
        .init(match: ["type": "turn.failed"], kind: "error", fields: ["text": "error.message"])
    ] }

    static var claude: [Parser] { [
        .init(match: ["type": "assistant"], each: "message.content"),
        .init(match: ["type": "text"], kind: "message", fields: ["text": "text"]),
        .init(match: ["type": "thinking"], kind: "reasoning", fields: ["text": "thinking"]),
        .init(match: ["type": "tool_use"], kind: "tool", fields: ["name": "name", "arguments": "input"])
    ] }
}
