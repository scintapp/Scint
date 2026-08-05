import Foundation
import OrderedCollections


struct Argument {
    let name: String
    let type: Value
    let required: Bool
    let defaultValue: Value?
}

enum Parser {
    static func parse(_ supplied: [String: Value], parameters: [Command.Parameter]) throws -> [String: Value] {
        let arguments = parameters.compactMap { parameter -> Argument? in
            guard case .argument(let name, let type, let required, let value) = parameter else { return nil }
            return Argument(name: name, type: type, required: required, defaultValue: value)
        }
        return try parse(supplied, arguments: arguments)
    }

    static func parse(_ input: [Value], parameters: [Command.Parameter]) throws -> [String: Value] {
        let arguments = parameters.compactMap { parameter -> Argument? in
            guard case .argument(let name, let type, let required, let value) = parameter else { return nil }
            return Argument(name: name, type: type, required: required, defaultValue: value)
        }
        return try parse(bind(input, to: arguments), arguments: arguments)
    }

    static func parse(_ supplied: [String: Value], parameters: [Harness.Parameter]) throws -> [String: Value] {
        let arguments = parameters.compactMap { parameter -> Argument? in
            switch parameter {
                case .argument(let name, let type, let required, let value):
                    return Argument(name: name, type: type, required: required, defaultValue: value)
                case .target(let name, let type, let value):
                    return Argument(name: name, type: type, required: false, defaultValue: value)
                default:
                    return nil
            }
        }
        return try parse(supplied, arguments: arguments)
    }

    static func parse(_ input: [Value], config: Config = [:], parameters: [Harness.Parameter]) throws -> [String: Value] {
        let arguments = parameters.compactMap { parameter -> Argument? in
            switch parameter {
                case .argument(let name, let type, let required, let value):
                    return Argument(name: name, type: type, required: required, defaultValue: value)
                case .target(let name, let type, let value):
                    return Argument(name: name, type: type, required: false, defaultValue: value)
                default:
                    return nil
            }
        }
        var supplied = bind(input, to: arguments)
        for (key, value) in config { supplied[key] = value }
        return try parse(supplied, arguments: arguments)
    }

    static func signals(_ chunk: String) -> [Signal] {
        chunk.split(whereSeparator: \.isNewline).compactMap { line in
            signal(String(line))
        }
    }

    static func continuation(_ value: Value) -> Value? {
        value.references.compactMap { ref -> Value? in
            guard ref.type == Transcript.self else { return nil }
            return Transcript.with(ref) { $0.property("thread_id") ?? $0.property("session_id") } ?? nil
        }.first
    }

    static func properties(_ signal: Signal) -> [(String, Value)] {
        guard case .updated(.string(let raw)) = signal, let properties = Properties.load(raw) else { return [] }
        return ["thread_id", "session_id"].compactMap { key in
            properties[key].flatMap(Value.init).map { (key, $0) }
        }
    }

    static func property(_ key: String, in value: Value) -> Value? {
        let marker = "\(key)="
        return value.rendered.reversed().compactMap { rendered -> Value? in
            guard let range = rendered.range(of: marker, options: .backwards) else { return nil }
            let suffix = rendered[range.upperBound...]
            let string = String(suffix.prefix { !$0.isWhitespace && $0 != "," })
            return string.isEmpty ? nil : .string(string)
        }.first
    }

    private static func signal(_ chunk: String) -> Signal? {
        let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let properties = Properties.load(trimmed) else { return .updated(.string(trimmed)) }

        switch (properties["type"]?.string ?? properties["event"]?.string)?.lowercased() {
            case "terminated":
                return properties["exitCode"]?.int == 0 ? .completed : .failed(.string(trimmed))
            case "item.completed":
                switch properties["item.type"]?.string?.lowercased() {
                    case "agent_message", "message", "reasoning", "command_execution", "command",
                        "mcp_tool_call", "function_call", "function":
                        return .updated(.string(trimmed))
                    default:
                        return nil
                }
            case "thread.started":
                return .updated(.string(trimmed))
            case "turn.started", "turn.completed", "item.started":
                return nil
            default:
                return .updated(.string(trimmed))
        }
    }

    private static func parse(_ supplied: [String: Value], arguments: [Argument]) throws -> [String: Value] {
        var parsed: [String: Value] = [:]

        for argument in arguments {
            if let value = supplied[argument.name] {
                parsed[argument.name] = try argument.type.construct(value, name: argument.name)
            } else if let value = argument.defaultValue {
                parsed[argument.name] = try argument.type.construct(value, name: argument.name)
            } else if argument.required {
                throw ParsingError.missingArgument(argument.name)
            }
        }

        let expected = Set(arguments.map(\.name))
        let unexpected = supplied.keys.filter { !expected.contains($0) }.sorted()
        guard unexpected.isEmpty else { throw ParsingError.unexpectedArguments(unexpected) }
        return parsed
    }

    private static func bind(_ values: [Value], to arguments: [Argument]) -> [String: Value] {
        var input = values
        var supplied: [String: Value] = [:]

        for argument in arguments {
            let acceptsInput = argument.required || !argument.type.references.isEmpty
            guard acceptsInput, let value = consume(&input, as: argument.type, name: argument.name) else { continue }
            supplied[argument.name] = value
        }
        return supplied
    }

    private static func consume(_ input: inout [Value], as type: Value, name: String) -> Value? {
        if let index = input.firstIndex(where: { (try? type.construct($0, name: name)) != nil }) {
            return input.remove(at: index)
        }

        guard let element = sequenceElement(in: type) else { return nil }
        var remaining: [Value] = []
        let values = input.compactMap { value -> Value? in
            guard (try? element.construct(value, name: name)) != nil else {
                remaining.append(value)
                return nil
            }
            return value
        }
        let value = Value.sequence(values)
        guard !values.isEmpty, (try? type.construct(value, name: name)) != nil else { return nil }
        input = remaining
        return value
    }

    private static func sequenceElement(in value: Value) -> Value? {
        switch value {
            case .sequence(let values): return values.first
            case .collection(let values) where values.count == 1: return values.values.first.flatMap(sequenceElement)
            default: return nil
        }
    }
}
