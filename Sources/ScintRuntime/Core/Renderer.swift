import Foundation


enum Intent: CaseIterable, Codable, Sendable {
    case compose, dispatch, evaluate, observe, search

    var rawValue: String { String(describing: self) }

    var forms: (label: String, running: String, completed: String) {
        switch self {
            case .compose: ("Compose", "Composing", "Composed")
            case .dispatch: ("Dispatch", "Dispatching", "Dispatched")
            case .observe: ("Observe", "Observing", "Observed")
            case .evaluate: ("Evaluate", "Evaluating", "Evaluated")
            case .search: ("Research", "Researching", "Researched")
        }
    }
}

enum Arguments {
    static func marshal(_ value: Value) -> [String] {
        switch value {
            case .bool(let value):
                return [String(value)]

            case .integer(let value):
                return [String(value)]

            case .decimal(let value):
                return [String(describing: value)]

            case .string(let value):
                return [value]

            case .date(let value):
                return [Value.formatter.string(from: value)]

            case .sequence(let values), .range(let values):
                return values.flatMap(marshal)

            case .collection(let values):
                return values.keys.sorted().flatMap { key -> [String] in
                    guard let value = values[key] else { return [] }
                    return marshal(value).map { "\(key)=\($0)" }
                }

            case .reference(let ref):
                if ref.type is Artifact.Type {
                    guard let path = Artifact.with(ref, { $0.rendered }), !path.isEmpty else { return [] }
                    return [path]
                }

                if ref.type is Command.Type {
                    Command.with(ref) { command -> [String] in
                        guard let executable = command.executable else { return [] }
                        return [executable] + command.arguments()
                    }
                }

                guard let url = Reference.Link.url(for: ref) else { return [] }
                return [url.absoluteString]
        }
    }

    static func marshal(_ values: [Value]) -> [String] { values.flatMap(marshal) }
}

struct Renderer {
    let origin: Reference
    var transcript: Reference

    private var closure: Reference? { Space.with(origin, { $0.closure }) }

    static func evaluation(_ origin: Reference, transcript: Reference, input: String) -> String {
        let map = Renderer(origin: origin, transcript: transcript)
        return map.assemble([
            Instructions.preamble,
            map.content(),
            map.interfaces(),
            map.thread(limit: 12),
            map.input(input)
        ])
    }

    private func assemble(_ sections: [String?]) -> String {
        sections.compactMap { $0 }.joined(separator: "\n\n")
    }

    private func content() -> String? {
        guard let closure, let materials = Closure.with(closure, { $0.materials }) else { return nil }
        let lines = materials
            .filter { !$0.descriptor.tags.contains("input") && $0.descriptor.published }
            .map { ref -> String in
                let description = ref.descriptor.description.trimmingCharacters(in: .whitespacesAndNewlines)
                let address = Reference.Link.url(for: ref)?.absoluteString ?? ref.id.uuidString
                return description.isEmpty
                ? "- \(ref.descriptor.name) — \(address)"
                : "- \(ref.descriptor.name) — \(address)\n  \(description)"
            }
        guard !lines.isEmpty else { return nil }
        let usage = "Use `scint.intent` with intent=search, action=search, and arguments.method=describe to read one, or method=list for everything here. "
            + "Every tool takes an address."
        return "## Documents\n\n\(usage)\n\n\(lines.joined(separator: "\n"))"
    }

    private func interfaces() -> String? {
        guard let closure, let record = Closure.with(closure, { $0 }) else { return nil }
        let lines = (record.harnesses + record.commands)
            .filter { $0.descriptor.published }
            .sorted { $0.descriptor.name < $1.descriptor.name }
            .map { ref -> String in
                let description = ref.descriptor.description.trimmingCharacters(in: .whitespacesAndNewlines)
                let address = Reference.Link.url(for: ref)?.absoluteString ?? ref.id.uuidString
                return description.isEmpty
                ? "- \(ref.descriptor.name) — \(address)"
                : "- \(ref.descriptor.name) — \(address)\n  \(description)"
            }
        guard !lines.isEmpty else { return nil }
        let usage = "Describe one with `scint.intent` (intent=search, action=search, arguments.method=describe), then run it with `scint.domain` (domain=interface, action=run, arguments.ref=its address)."
        return "## Capabilities\n\n\(usage)\n\n\(lines.joined(separator: "\n"))"
    }

    private func thread(limit: Int) -> String? {
        guard let records = Transcript.with(transcript, { $0.records }) else { return nil }
        let turns = records.compactMap(turn)
        guard !turns.isEmpty else { return nil }
        return "## Thread\n\n\(turns.suffix(limit).joined(separator: "\n\n"))"
    }

    private func turn(_ chunk: Map) -> String? {
        guard let text = text(chunk.value)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty
        else { return nil }
        return chunk.origin.type == Material.self ? "**Request** — \(text)" : "**Response** — \(text)"
    }

    private func text(_ value: Value) -> String? {
        switch value {
            case .string(let text): return text
            case .collection(let fields):
                guard case .string(let text)? = fields["text"] else { return nil }
                return text
            default: return nil
        }
    }

    private func input(_ input: String) -> String? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : "## Request\n\n\(text)"
    }

    static func reference(_ ref: Reference) -> String {
        switch ref.type {
            case is Artifact.Type: return Artifact.with(ref, { $0.rendered }) ?? ""
            case is Command.Type: return Command.with(ref, { $0.rendered }) ?? ""
            case is Harness.Type: return Harness.with(ref, { $0.rendered }) ?? ""
            case is Material.Type: return Material.with(ref, { $0.rendered }) ?? ""
            case is Transcript.Type: return Transcript.with(ref, { $0.rendered }) ?? ""
            case is Closure.Type: return Closure.with(ref, { $0.rendered }) ?? ""
            case is Bridge.Type: return Bridge.with(ref, { $0.rendered }) ?? ""
            case is Space.Type: return Space.with(ref, { $0.rendered }) ?? ""
            default: return ""
        }
    }
    
    static func value(_ value: Value) -> [String] {
        switch value {
            case .bool(let value): return [String(value)]
            case .date(let value): return [Value.formatter.string(from: value)]
            case .integer(let value): return [String(value)]
            case .decimal(let value): return [String(describing: value)]
            case .string(let value): return [value]
            case .sequence(let values), .range(let values): return values.flatMap { Renderer.value($0) }
            case .collection(let values):
                return values.keys.sorted().flatMap { key -> [String] in
                    guard let value = values[key] else { return [] }
                    return Renderer.value(value).map { "\(key)=\($0)" }
                }
            case .reference(let ref):
                let rendered = Renderer.reference(ref)
                return rendered.isEmpty ? [] : [rendered]
        }
    }

}

struct Instructions: Codable, Sendable {
    static var preamble: String {
        """
        You are working in a space: an environment holding documents you can read and \
        capabilities you can invoke. Everything below is a summary — use your tools to \
        reach the current state of anything you need.

        Capabilities are available to you as tools. Call them directly.
        """
    }

    static var compose: String {
        """
        dispatch
        """
    }


    static var evaluate: String {
        """
        evaluate
        """
    }

    static var observe: String {
        """
        observe
        """
    }

    static var search: String {
        """
        search
        """
    }
}

struct Reading: Codable, Sendable, Equatable {
    var match: [String: String] = [:]
    var each: String? = nil
    var kind: String? = nil
    var fields: [String: String] = [:]

    func matches(_ properties: Properties) -> Bool {
        match.allSatisfy { path, expected in
            properties[path]?.string?.lowercased() == expected.lowercased()
        }
    }

    static func read(_ value: Value, using readings: [Reading] = .vendors) -> [Value] {
        let content = value.rendered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, content != "Reading additional input from stdin..." else { return [] }
        guard let properties = Properties.load(content) else { return [.collection(["type": .string("message"), "text": .string(content)])] }
        return read(properties, using: readings)
    }

    static func read(_ properties: Properties, using readings: [Reading] = .vendors) -> [Value] {
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

extension Array where Element == Reading {
    static var vendors: [Reading] { codex + claude }

    static var codex: [Reading] { [
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

    static var claude: [Reading] { [
        .init(match: ["type": "assistant"], each: "message.content"),
        .init(match: ["type": "text"], kind: "message", fields: ["text": "text"]),
        .init(match: ["type": "thinking"], kind: "reasoning", fields: ["text": "thinking"]),
        .init(match: ["type": "tool_use"], kind: "tool", fields: ["name": "name", "arguments": "input"])
    ] }
}
