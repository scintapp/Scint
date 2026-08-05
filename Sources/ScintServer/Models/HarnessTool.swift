
import Foundation
import MCP

struct HarnessTool: Sendable {
    static let prefix = "Scint.harness."
    let harness: Reference
    let origin: Reference

    init(_ harness: Reference, origin: Reference) {
        self.harness = harness
        self.origin = origin
    }

    var name: String {
        let slug = harness.descriptor.name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        return Self.prefix + (slug.isEmpty ? "harness" : slug) + "_" + harness.id.uuidString.prefix(8).lowercased()
    }

    var tool: MCP.Tool? {
        Harness.with(harness) { harness in
            let descriptor = harness.ref.descriptor
            return MCP.Tool(
                name: name,
                title: descriptor.name,
                description: descriptor.description.isEmpty ? "Run \(descriptor.name)." : descriptor.description,
                inputSchema: Self.inputSchema(harness.parameters),
                annotations: .init(
                    title: descriptor.name,
                    readOnlyHint: false,
                    destructiveHint: true,
                    idempotentHint: false,
                    openWorldHint: true
                )
            )
        }
    }

    func call(_ arguments: [String: MCP.Value]?) async -> CallTool.Result {
        guard let parameters = Harness.with(harness, { $0.parameters }) else {
            return Self.failure("Scint harness is unavailable.")
        }

        let values: [String: Value]
        do {
            let supplied = try Self.values(arguments ?? [:], parameters: parameters, available: references)
            values = try Parser.parse(supplied, parameters: parameters)
        } catch {
            return Self.failure(String(describing: error))
        }

        let (stream, continuation) = AsyncStream<Signal>.makeStream()
        let environment = ["Scint_CONTEXT": origin.contextId.uuidString.lowercased()]
        guard let result = Harness.with(harness, { harness in
            harness.run(values, environment: environment) { signal in
                continuation.yield(signal)
                if signal.terminal { continuation.finish() }
            }
        }) ?? nil else {
            continuation.finish()
            return Self.failure("Scint harness could not be started.")
        }
        if let error = result.error, !error.isEmpty {
            continuation.finish()
            return Self.failure(error)
        }

        var output: [String] = []
        var failed = false
        for await signal in stream {
            switch signal {
                case .updated(let value): output.append(contentsOf: value.rendered)
                case .failed(let value): output.append(contentsOf: value.rendered); failed = true
                case .eval, .started, .completed: break
            }
        }
        return CallTool.Result(
            content: [.text(text: output.joined(separator: "\n"), annotations: nil, _meta: nil)],
            isError: failed
        )
    }

    static func all(in origin: Reference) -> [Self] {
        guard let closure = closure(for: origin) else { return [] }
        let refs = Closure.with(closure, { $0.harnesses }) ?? []
        return refs
            .filter { $0.descriptor.published }
            .sorted { $0.descriptor.name < $1.descriptor.name }
            .map { Self($0, origin: origin) }
    }

    static func find(_ name: String, in origin: Reference) -> Self? {
        all(in: origin).first { $0.name == name }
    }

    static func inputSchema(_ parameters: [Harness.Parameter]) -> MCP.Value {
        let arguments = parameters.compactMap { parameter -> (name: String, type: Value, required: Bool)? in
            guard case .argument(let name, let type, let required, _) = parameter else { return nil }
            return (name, type, required)
        }
        let properties = arguments.reduce(into: [String: MCP.Value]()) { properties, argument in
            properties[argument.name] = schema(argument.type)
        }
        let required = arguments.filter(\.required).map { MCP.Value.string($0.name) }
        var schema: [String: MCP.Value] = [
            "type": .string("object"),
            "properties": .object(properties),
            "additionalProperties": .bool(false)
        ]
        if !required.isEmpty { schema["required"] = .array(required) }
        return .object(schema)
    }

    static func schema(_ value: Value) -> MCP.Value {
        switch value {
            case .bool: return .object(["type": .string("boolean")])
            case .integer: return .object(["type": .string("integer")])
            case .decimal: return .object(["type": .string("number")])
            case .string, .reference: return .object(["type": .string("string")])
            case .sequence(let values) where values.count > 1:
                return .object(["enum": .array(values.map(literal))])
            case .sequence(let values):
                return .object([
                    "type": .string("array"),
                    "items": values.first.map(schema) ?? .object([:])
                ])
            case .collection(let values) where values.count == 1:
                return values.values.first.map(schema) ?? .object([:])
            case .collection(let values):
                let keys = values.keys.sorted()
                return .object([
                    "type": .string("object"),
                    "properties": .object(values.mapValues(schema)),
                    "required": .array(keys.map(MCP.Value.string)),
                    "additionalProperties": .bool(false)
                ])
        }
    }

    static func literal(_ value: Value) -> MCP.Value {
        switch value {
            case .bool(let value): return .bool(value)
            case .integer(let value): return .int(value)
            case .decimal(let value): return .double(NSDecimalNumber(decimal: value).doubleValue)
            case .string(let value): return .string(value)
            case .sequence(let values): return .array(values.map(literal))
            case .collection(let values): return .object(values.mapValues(literal))
            case .reference(let ref): return .string(ref.id.uuidString.lowercased())
        }
    }

    static func values( _ supplied: [String: MCP.Value], parameters: [Harness.Parameter], available: Set<Reference>) throws -> [String: Value] {
        let arguments = parameters.reduce(into: [String: Value]()) { arguments, parameter in
            guard case .argument(let name, let type, _, _) = parameter else { return }
            arguments[name] = type
        }
        return try supplied.reduce(into: [String: Value]()) { result, entry in
            guard let template = arguments[entry.key] else {
                throw ParsingError.unexpectedArguments([entry.key])
            }
            result[entry.key] = try value(entry.value, as: template, available: available, name: entry.key)
        }
    }

    static func value(_ supplied: MCP.Value, as template: Value, available: Set<Reference>, name: String) throws -> Value {
        switch template {
            case .bool:
                guard case .bool(let value) = supplied else { throw invalid(name) }
                return .bool(value)
            case .integer:
                guard case .int(let value) = supplied else { throw invalid(name) }
                return .integer(value)
            case .decimal:
                switch supplied {
                    case .int(let value): return .decimal(Decimal(value))
                    case .double(let value): return .decimal(Decimal(value))
                    default: throw invalid(name)
                }
            case .string:
                guard case .string(let value) = supplied else { throw invalid(name) }
                return .string(value)
            case .reference(let expected):
                guard case .string(let value) = supplied,
                      let id = UUID(uuidString: value) ?? URL(string: value).flatMap({ UUID(uuidString: $0.lastPathComponent) }),
                      let ref = available.first(where: {
                          ($0.id == id || $0.descriptorId == id) && $0.typeId == expected.typeId
                      })
                else { throw ParsingError.invalid("Argument \(name) references an unavailable value.") }
                return .reference(ref)
            case .sequence(let alternatives) where alternatives.count > 1:
                for alternative in alternatives {
                    if let value = try? value(supplied, as: alternative, available: available, name: name) { return value }
                }
                throw invalid(name)
            case .sequence(let values):
                guard case .array(let supplied) = supplied else { throw invalid(name) }
                guard let element = values.first else {
                    return .sequence(try supplied.map { try untypedValue($0, name: name) })
                }
                return .sequence(try supplied.map { try value($0, as: element, available: available, name: name) })
            case .collection(let values):
                if case .object(let supplied) = supplied, Set(supplied.keys) == Set(values.keys) {
                    return .collection(try supplied.reduce(into: [String: Value]()) { result, entry in
                        guard let child = values[entry.key] else { throw invalid(name) }
                        result[entry.key] = try value(entry.value, as: child, available: available, name: name)
                    })
                }
                guard values.count == 1, let child = values.values.first else { throw invalid(name) }
                return try value(supplied, as: child, available: available, name: name)
        }
    }

    static func untypedValue(_ value: MCP.Value, name: String) throws -> Value {
        switch value {
            case .null: throw invalid(name)
            case .bool(let value): return .bool(value)
            case .int(let value): return .integer(value)
            case .double(let value): return .decimal(Decimal(value))
            case .string(let value): return .string(value)
            case .data(_, let value): return .string(value.base64EncodedString())
            case .array(let values): return .sequence(try values.map { try untypedValue($0, name: name) })
            case .object(let values): return .collection(try values.mapValues { try untypedValue($0, name: name) })
        }
    }

    static func invalid(_ name: String) -> ParsingError {
        .invalid("Argument \(name) has an invalid value type.")
    }

    static func failure(_ message: String) -> CallTool.Result {
        CallTool.Result(content: [.text(text: message, annotations: nil, _meta: nil)], isError: true)
    }

    private var references: Set<Reference> {
        var refs: Set<Reference> = [origin]
        guard let closure = Self.closure(for: origin) else { return refs }
        refs.insert(closure)
        let scoped = Closure.with(closure) {
            Set([$0.owner, $0.input] + $0.content + Array($0.interfaces))
        } ?? []
        refs.formUnion(scoped)
        return refs
    }

    private static func closure(for origin: Reference) -> Reference? {
        Space.with(origin, { $0.closure }) ?? Workspace.with(origin, { $0.closure })
    }
}
