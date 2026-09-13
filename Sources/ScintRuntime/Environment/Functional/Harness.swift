import Foundation


struct Harness: Functional {
    let ref: Reference
    let intent: Intent
    let command: Reference
    let parameters: [Parameter]

    enum Parameter: Codable, Sendable, Equatable {
        case argument(name: String, type: Value, required: Bool = false, default: Value? = nil)
        case command(content: String, value: Value? = nil)
        case requirement(name: String, type: Value, value: Value)
        case target(name: String, type: Value, default: Value? = nil)
    }

    init(_ ref: Reference = .init(Self.self)) {
        self.ref = ref
        self.command = ref
        self.intent = .compose
        self.parameters = []
    }

    init(_ ref: Reference, command: Reference, intent: Intent, params: [Parameter]) {
        self.ref = ref
        self.command = command
        self.intent = intent
        self.parameters = params
    }

    var rendered: String {
        var lines = ["\(ref.descriptor.name) (harness)"]
        if !ref.descriptor.description.isEmpty { lines.append(ref.descriptor.description) }
        lines.append("intent: \(intent)")
        return lines.joined(separator: "\n")
    }

    func arguments(with values: [String: Value]? = nil) -> [String] {
        parameters.flatMap { parameter in
            switch parameter {
                case .argument(let name, _, _, let value):
                    return (values?[name] ?? value).map(Arguments.marshal) ?? []
                case .command, .requirement, .target:
                    return []
            }
        }
    }

    func parse(_ arguments: [String: Value], input: Value? = nil) throws -> [String: Value] {
        var arguments = arguments
        var parsed: [String: Value] = [:]
        var command: [String: Value] = [:]
        var expected: Set<String> = []

        if let input, parameters.contains(where: { param in
            guard case .argument(let name, _, _, _) = param else { return false }
            return name == "input"
        }) { arguments["input"] = input }

        for parameter in parameters {
            switch parameter {
                case .argument(let name, let type, let required, let fallback):
                    expected.insert(name)
                    if let value = arguments[name] { parsed[name] = try type.construct(value, name: name) }
                    else if let fallback { parsed[name] = try type.construct(fallback, name: name) }
                    else if required { throw ParsingError.missingArgument(name) }

                case .requirement(let name, let type, let value):
                    expected.insert(name)
                    parsed[name] = try type.construct(arguments[name] ?? value, name: name)

                case .target(let name, let type, let fallback):
                    expected.insert(name)
                    if let value = arguments[name] { parsed[name] = try type.construct(value, name: name) }
                    else if let fallback { parsed[name] = try type.construct(fallback, name: name) }

                case .command(let content, let value):
                    command[content] = value ?? .string("")
            }
        }

        let unexpected = arguments.keys.filter { !expected.contains($0) }.sorted()
        guard unexpected.isEmpty else { throw ParsingError.unexpectedArguments(unexpected) }
        guard let values = try Command.with(self.command, { try $0.parse(command) })
        else { throw RuntimeError.context(.missing(self.command)) }
        parsed.merge(values) { _, value in value }
        return parsed
    }

    func run(_ values: [String: Value]? = nil, _ env: [String: String] = [:], _ output: ((String) -> Void)? = nil) -> (pid: Int32, error: String?)? {
        guard let command = Command.with(self.command, { $0 }), let executable = command.executable
        else { return nil }
        let result = Runtime.shared.services.start(
            executable,
            args: command.arguments(with: values) + arguments(with: values),
            env: env
        )
        if let output, let pid = result?.pid, result?.error == nil { Runtime.shared.services.output(pid: pid, output) }
        return result
    }

    static func register(_ name: String, command: Reference, intent: Intent, parameters: [Parameter] = []) -> Reference {
        let instance = Self(.init(Self.self), command: command, intent: intent, params: parameters)
        Descriptor.new(instance.ref, name: name, tags: ["harness"])
        Library.shared.store(for: instance.ref)?.add(instance.ref, instance)
        return instance.ref
    }
}
