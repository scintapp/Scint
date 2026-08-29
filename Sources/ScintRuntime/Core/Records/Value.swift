import Foundation


indirect enum Value: Codable, Sendable, Equatable {
    case bool(Bool)
    case integer(Int)
    case decimal(Decimal)
    case string(String)
    case date(Date)
    case reference(Reference)
    case sequence([Value])
    case collection([String: Value])

    static func reference(_ type: Resolvable.Type) -> Value { .reference(Reference(type)) }
    static func sequence(_ value: Value) -> Value { .sequence([value]) }

    static var formatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    var type: Any.Type? {
        switch self {
            case .bool: return Bool.self
            case .date: return Date.self
            case .integer: return Int.self
            case .decimal: return Decimal.self
            case .string: return String.self
            case .sequence: return Array<Value>.self
            case .collection: return Dictionary<String, Value>.self
            case .reference(let ref): return ref.type
        }
    }

    var rendered: [String] { render() }

    var described: String {
        switch self {
            case .bool: return "<true|false>"
            case .date: return "<date>"
            case .integer: return "<integer>"
            case .decimal: return "<number>"
            case .string(let value): return value.isEmpty ? "<string>" : "<\(value)>"
            case .reference(let ref): return "<\(ref.type.map { "\($0)" } ?? "reference")>"
            case .sequence(let values):
                if values.isEmpty { return "<reference>" }
                if values.count == 1 { return "\(values[0].described)..." }
                let choices = values.compactMap { if case .string(let value) = $0 { value } else { nil } }
                return choices.count == values.count ? "<\(choices.joined(separator: "|"))>" : "<\(values.map(\.described).joined(separator: "|"))>"
            case .collection(let values):
                return values.keys.sorted().map { key in
                    guard let value = values[key] else { return key }
                    return "\(key) \(value.described)"
                }.joined(separator: " ")
        }
    }

    var references: [Reference] {
        switch self {
            case .reference(let ref): return [ref]
            case .sequence(let values): return values.flatMap(\.references)
            case .collection(let values): return values.values.flatMap(\.references)
            default: return []
        }
    }

    func construct(_ supplied: Value, name: String) throws -> Value {
        switch (self, supplied) {
            case (.bool, .bool), (.integer, .integer), (.decimal, .decimal), (.string, .string):
                return supplied

            case (.date, .date):
                return supplied

            case (.date, .string(let value)) where Value.formatter.date(from: value) != nil:
                return .date(Value.formatter.date(from: value)!)

            case (.bool, .string(let value)) where Bool(value) != nil:
                return .bool(Bool(value)!)

            case (.integer, .string(let value)) where Int(value) != nil:
                return .integer(Int(value)!)

            case (.decimal, .string(let value)) where Decimal(string: value) != nil:
                return .decimal(Decimal(string: value)!)

            case (.reference(let expected), .reference(let received)) where expected.typeId == received.typeId:
                return supplied

            case (.sequence(let alternatives), .reference) where alternatives.isEmpty:
                return supplied

            case (.sequence(let alternatives), _) where alternatives.count > 1:
                guard alternatives.contains(where: { (try? $0.construct(supplied, name: name)) != nil })
                        else { throw ParsingError.invalid("Argument \(name) is not an allowed value.") }
                return supplied

            case (.sequence(let template), .sequence(let values)):
                guard let element = template.first else { return supplied }
                return .sequence(try values.map { try element.construct($0, name: name) })

            case (.collection(let template), .collection(let values)):
                var constructed: [String: Value] = [:]
                for (key, expected) in template {
                    guard let value = values[key] else { throw ParsingError.invalid("Argument \(name) is missing \(key).") }
                    constructed[key] = try expected.construct(value, name: name)
                }
                guard Set(values.keys) == Set(template.keys) else { throw ParsingError.invalid("Argument \(name) has an invalid shape.") }
                return .collection(constructed)

            case (.collection(let template), _):
                guard template.count == 1, let (key, expected) = template.first else {
                    throw ParsingError.invalid("Argument \(name) expects a collection.")
                }
                return .collection([key: try expected.construct(supplied, name: name)])

            default:
                throw ParsingError.invalid("Argument \(name) has an invalid value type.")
        }
    }

    private func render() -> [String] {
        switch self {
            case .bool(let value): return [String(value)]
            case .date(let value): return [Value.formatter.string(from: value)]
            case .integer(let value): return [String(value)]
            case .decimal(let value): return [String(describing: value)]
            case .string(let value): return [value]
            case .sequence(let values): return values.flatMap { $0.render() }
            case .collection(let values):
                return values.keys.sorted().flatMap { key -> [String] in
                    guard let value = values[key] else { return [] }
                    let rendered = value.render()
                    return ["\(key)=\(rendered.joined(separator: ","))"]
                }
            case .reference(let ref):
                let rendered = Runtime.shared.rendered(ref)
                return rendered.isEmpty ? [] : [rendered]
        }
    }
}

struct Chunk: Keyable {
    let key: Key
    let origin: Reference
    let value: Value

    init(_ ref: Reference, _ origin: Reference, _ value: Value) {
        self.key = .branch(UUID(), ref)
        self.origin = origin
        self.value = value
    }

    var name: String { origin.descriptor.name }
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
        .init(match: ["type": "item.completed", "item.type": "web_search"], kind: "tool", fields: ["name": "item.query"])
    ] }

    static var claude: [Reading] { [
        .init(match: ["type": "assistant"], each: "message.content"),
        .init(match: ["type": "text"], kind: "message", fields: ["text": "text"]),
        .init(match: ["type": "thinking"], kind: "reasoning", fields: ["text": "thinking"]),
        .init(match: ["type": "tool_use"], kind: "tool", fields: ["name": "name", "arguments": "input"])
    ] }
}
