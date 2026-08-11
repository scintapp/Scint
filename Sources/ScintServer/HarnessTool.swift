import Foundation


struct ServerTool: Sendable {
    struct Invocation: Sendable {
        let text: String
        let isError: Bool
    }

    let interface: Reference
    let origin: Reference

    var name: String {
        let kind = interface.type == Harness.self ? "harness" : "command"
        return "Scint.\(kind).\(interface.id.uuidString.lowercased())"
    }

    var definition: Property {
        let descriptor = interface.descriptor
        let value: [String: Property] = [
            "name": .string(name),
            "title": .string(descriptor.name),
            "description": .string(descriptor.description.isEmpty ? "Run \(descriptor.name)." : descriptor.description),
            "inputSchema": inputSchema
        ]
        return .object(value)
    }

    func call(_ arguments: Properties) async -> Invocation {
        let values: [String: Value]
        do {
            values = try Parser.parse(try supplied(arguments), for: interface)
        } catch {
            return Invocation(text: String(describing: error), isError: true)
        }

        let (stream, continuation) = AsyncStream<Signal>.makeStream()
        guard let result = dispatch(values, output: { signal in
            continuation.yield(signal)
            if signal.terminal { continuation.finish() }
        }) else {
            continuation.finish()
            return Invocation(text: "Scint tool could not be started.", isError: true)
        }
        if let error = result.error, !error.isEmpty {
            continuation.finish()
            return Invocation(text: error, isError: true)
        }

        var output: [String] = []
        var failed = false
        for await signal in stream {
            switch signal {
                case .updated(let value): output.append(contentsOf: value.rendered)
                case .failed(let value): output.append(contentsOf: value.rendered); failed = true
                case .stopped: failed = true
                default: break
            }
        }
        return Invocation(text: output.joined(separator: "\n"), isError: failed)
    }

    static func all(in origin: Reference) -> [Self] {
        guard let closure = closure(for: origin) else { return [] }
        let interfaces = Closure.with(closure, { $0.interfaces }) ?? []
        return interfaces
            .filter { ($0.type == Command.self || $0.type == Harness.self) && $0.descriptor.published }
            .map { Self(interface: $0, origin: origin) }
            .sorted { $0.name < $1.name }
    }

    static func find(_ name: String, in origin: Reference) -> Self? {
        all(in: origin).first { $0.name == name }
    }

    private var inputSchema: Property {
        let properties = arguments.reduce(into: [String: Property]()) { properties, argument in
            properties[argument.name] = Self.schema(argument.type)
        }
        let required = arguments.filter(\.required).map { Property.string($0.name) }
        var schema: [String: Property] = [
            "type": .string("object"),
            "properties": .object(properties),
            "additionalProperties": .bool(false)
        ]
        if !required.isEmpty { schema["required"] = .array(required) }
        return .object(schema)
    }

    private var arguments: [(name: String, type: Value, required: Bool)] {
        if let parameters = Command.with(interface, { $0.parameters }) {
            return parameters.compactMap { parameter in
                guard case .argument(let name, let type, let required, _) = parameter else { return nil }
                return (name, type, required)
            }
        }
        return Harness.with(interface, { $0.parameters })?.compactMap { parameter in
            guard case .argument(let name, let type, let required, _) = parameter else { return nil }
            return (name, type, required)
        } ?? []
    }

    private func dispatch(_ values: [String: Value], output: @escaping (Signal) -> Void) -> (pid: Int32, error: String?)? {
        let environment = ["SCINT_CONTEXT": origin.contextId.uuidString.lowercased()]
        if let command = Command.with(interface, { $0 }) {
            return command.dispatch(rendered: command.rendered(with: values), environment: environment, output: output)
        }
        guard let harness = Harness.with(interface, { $0 }) else { return nil }
        return Command.with(harness.command) { command in
            command.dispatch(
                rendered: command.rendered(with: values) + harness.rendered(with: values),
                environment: environment,
                output: output
            )
        } ?? nil
    }

    private func supplied(_ values: Properties) throws -> [String: Value] {
        let templates = arguments.reduce(into: [String: Value]()) { $0[$1.name] = $1.type }
        let supplied = values.mergedObject
        return try supplied.reduce(into: [String: Value]()) { result, entry in
            guard let template = templates[entry.key] else { throw ParsingError.unexpectedArguments([entry.key]) }
            result[entry.key] = try Self.value(entry.value, as: template, available: references, name: entry.key)
        }
    }

    private var references: Set<Reference> {
        var refs: Set<Reference> = [origin]
        guard let closure = Self.closure(for: origin) else { return refs }
        refs.insert(closure)
        let scoped = Closure.with(closure) {
            Set([$0.origin, $0.input] + $0.content + Array($0.interfaces))
        } ?? []
        refs.formUnion(scoped)
        return refs
    }

    private static func schema(_ value: Value) -> Property {
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
                return .object([
                    "type": .string("object"),
                    "properties": .object(values.mapValues(schema)),
                    "required": .array(values.keys.sorted().map(Property.string)),
                    "additionalProperties": .bool(false)
                ])
        }
    }

    private static func literal(_ value: Value) -> Property {
        switch value {
            case .bool(let value): return .bool(value)
            case .integer(let value): return .integer(value)
            case .decimal(let value): return .decimal(NSDecimalNumber(decimal: value).doubleValue)
            case .string(let value): return .string(value)
            case .sequence(let values): return .array(values.map(literal))
            case .collection(let values): return .object(values.mapValues(literal))
            case .reference(let ref): return .string(ref.id.uuidString.lowercased())
        }
    }

    private static func value(_ supplied: Property, as template: Value, available: Set<Reference>, name: String) throws -> Value {
        switch template {
            case .bool:
                guard case .bool(let value) = supplied else { throw invalid(name) }
                return .bool(value)
            case .integer:
                guard case .integer(let value) = supplied else { throw invalid(name) }
                return .integer(value)
            case .decimal:
                switch supplied {
                    case .integer(let value): return .decimal(Decimal(value))
                    case .decimal(let value): return .decimal(Decimal(value))
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

    private static func untypedValue(_ value: Property, name: String) throws -> Value {
        switch value {
            case .null: throw invalid(name)
            case .bool(let value): return .bool(value)
            case .integer(let value): return .integer(value)
            case .decimal(let value): return .decimal(Decimal(value))
            case .string(let value): return .string(value)
            case .array(let values): return .sequence(try values.map { try untypedValue($0, name: name) })
            case .object(let values): return .collection(try values.mapValues { try untypedValue($0, name: name) })
        }
    }

    private static func invalid(_ name: String) -> ParsingError {
        .invalid("Argument \(name) has an invalid value type.")
    }

    private static func closure(for origin: Reference) -> Reference? {
        Space.with(origin, { $0.closure }) ?? Workspace.with(origin, { $0.closure })
    }
}
