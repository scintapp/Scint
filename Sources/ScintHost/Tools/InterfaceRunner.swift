import Foundation
import OSLog


/// Runs one command or harness.
///
/// Not a tool itself. Interfaces are authored by whoever uses the app, so there can be any number
/// of them and they change under you — a tool per interface would make `tools/list` a function of
/// user content, churning on every edit and naming everything by UUID. `scint.interfaces.call`
/// takes an address like every other tool in the kit, and this does the work behind it.
///
/// The input schema is derived from the runtime's own parameter templates, and is what
/// `scint.interfaces.describe` reports so a caller knows what to pass.
struct InterfaceRunner {
    private static let logger = Logger(subsystem: "com.kaechle.scint", category: "MCPTool")
    /// How long a call waits before returning what it has.
    ///
    /// A bound has to exist: `tools/call` is request/response over a connection that closes, so
    /// MCP's progress notifications — the mechanism for long calls — need a streaming transport
    /// this server does not have. Without a bound the call hangs until the *client's* timeout
    /// fires, which returns nothing at all. Timing out first is what preserves partial output.
    ///
    /// So the number is sized to come in under a client's own timeout, not to fit the work. Set
    /// `timeout` in a space's config to raise it where you control both ends. Work that genuinely
    /// runs for minutes is not a call — it is `scint.structures.start`, which is unbounded because
    /// it does not block a request.
    static let defaultTimeout: TimeInterval = 55

    let interface: Reference
    let origin: Reference



    func call(_ arguments: Properties) async -> ToolResult {
        let values: [String: Value]
        do {
            let given = try supplied(arguments)
            if let command = Command.with(interface, { $0 }) { values = try command.bind(given) }
            else if let harness = Harness.with(interface, { $0 }) { values = try harness.bind(given) }
            else { throw ParsingError.invalid("No functional object found for \(interface.id).") }
        } catch {
            return ToolResult(text: String(describing: error), isError: true)
        }

        let (stream, continuation) = AsyncStream<String>.makeStream()

        let started: (pid: Int32, error: String?)? = await withCheckedContinuation { resume in
            DispatchQueue.global(qos: .userInitiated).async {
                resume.resume(returning: dispatch(values, output: { line in
                    continuation.yield(line)
                    if Self.exit(of: line) != nil { continuation.finish() }
                }))
            }
        }

        guard let result = started else {
            Self.logger.error("Tool \(interface.id.uuidString, privacy: .public) dispatch timed out")
            continuation.finish()
            return ToolResult(text: "Scint tool could not be started.", isError: true)
        }
        if let error = result.error, !error.isEmpty {
            Self.logger.error("Tool \(interface.id.uuidString, privacy: .public) pid \(result.pid) failed to start: \(error, privacy: .public)")
            continuation.finish()
            return ToolResult(text: error, isError: true)
        }
        Self.logger.info("Tool \(interface.id.uuidString, privacy: .public) dispatched pid \(result.pid)")

        let watchdog = Task {
            try? await Task.sleep(for: .seconds(timeout))
            continuation.finish()
        }
        
        defer { watchdog.cancel() }

        var output: [String] = []
        var terminated = false
        var failed = false
        for await line in stream {
            let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if let code = Self.exit(of: text) {
                terminated = true
                failed = code != 0
                if failed { output.append(text) }
            } else {
                output.append(text)
            }
        }

        guard terminated else {
            Self.logger.error("Tool \(interface.id.uuidString, privacy: .public) pid \(result.pid) timed out after \(Int(timeout))s with \(output.count) output lines")
            let partial = output.joined(separator: "\n")
            return ToolResult(
                text: partial.isEmpty
                ? "Scint tool did not report completion within \(Int(timeout))s."
                : "\(partial)\n\n[Scint: no completion within \(Int(timeout))s; output may be partial.]",
                isError: true
            )
        }
        Self.logger.info("Tool \(interface.id.uuidString, privacy: .public) pid \(result.pid) completed failed=\(failed) lines=\(output.count)")
        return ToolResult(text: output.joined(separator: "\n"), isError: failed)
    }

    static func exit(of line: String) -> Int? {
        func code(_ value: String) -> Int? {
            guard let properties = Properties.load(value),
                  (properties["type"]?.string ?? properties["event"]?.string)?.lowercased() == "terminated"
            else { return nil }
            return properties["exitCode"]?.int ?? 0
        }
        if let found = code(line) { return found }
        guard let brace = line.lastIndex(of: "{"), brace != line.startIndex else { return nil }
        return code(String(line[brace...]))
    }

    var timeout: TimeInterval {
        guard case .integer(let seconds)? = Space.with(origin, { $0.config["timeout"] }) ?? nil,
              seconds > 0
        else { return Self.defaultTimeout }
        return TimeInterval(seconds)
    }

    var inputSchema: Property {
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

    private func dispatch(_ values: [String: Value], output: @escaping (String) -> Void) -> (pid: Int32, error: String?)? {
        let environment = ["SCINT_CONTEXT": origin.contextId.uuidString.lowercased()]
        if let command = Command.with(interface, { $0 }) {
            return command.dispatch(command.rendered(with: values), environment: environment, output: output)
        }
        guard let harness = Harness.with(interface, { $0 }) else { return nil }
        return Command.with(harness.command) { command in
            command.dispatch(
                command.rendered(with: values) + harness.rendered(with: values),
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
            case .date: return .object(["type": .string("string"), "format": .string("date-time")])
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
            case .date(let value): return .string(Value.formatter.string(from: value))
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
            case .date:
                guard case .string(let value) = supplied,
                      let parsed = Value.formatter.date(from: value)
                else { throw invalid(name) }
                return .date(parsed)
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
