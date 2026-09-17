import Foundation


struct Command: Functional {
    let ref: Reference
    let artifact: Reference
    let parameters: [Parameter]

    enum Parameter: Codable, Sendable, Equatable {
        case argument(name: String, type: Value, required: Bool = false, default: Value? = nil)
        case fixed(Value)
        case requirement(name: String, type: Value, value: Value)
    }

    init(_ ref: Reference, artifact: Reference, parameters: [Parameter]) {
        self.ref = ref
        self.artifact = artifact
        self.parameters = parameters
    }

    var rendered: String {
        var lines = ["\(ref.descriptor.name) (command)"]
        if !ref.descriptor.description.isEmpty { lines.append(ref.descriptor.description) }
        return lines.joined(separator: "\n")
    }

    var executable: String? { Artifact.with(artifact, { $0.handler.executable }) ?? nil }

    func arguments(with values: [String: Value]? = nil) -> [String] {
        parameters.flatMap { parameter in
            switch parameter {
                case .argument(let name, _, _, let value):
                    return (values?[name] ?? value).map(Arguments.marshal) ?? []
                case .fixed(let value): return Arguments.marshal(value)
                case .requirement: return []
            }
        }
    }

    func parse(_ arguments: [String: Value]) throws -> [String: Value] {
        var parsed: [String: Value] = [:]
        var expected: Set<String> = []

        for parameter in parameters {
            guard case .argument(let name, let type, let required, let fallback) = parameter else { continue }
            expected.insert(name)
            if let value = arguments[name] { parsed[name] = try type.construct(value, name: name) }
            else if let fallback { parsed[name] = try type.construct(fallback, name: name) }
            else if required { throw ParsingError.missingArgument(name) }
        }

        let unexpected = arguments.keys.filter { !expected.contains($0) }.sorted()
        guard unexpected.isEmpty else { throw ParsingError.unexpectedArguments(unexpected) }
        return parsed
    }

    func run(_ values: [String: Value]? = nil, _ env: [String: String] = [:], _ output: ((String) -> Void)? = nil) -> (pid: Int32, error: String?)? {
        guard let executable else { return nil }
        let result = Runtime.shared.services.start(executable, args: arguments(with: values), env: env)
        if let output, let pid = result?.pid, result?.error == nil { Runtime.shared.services.output(pid: pid, output) }
        return result
    }

    func matches(_ other: Command) -> Bool { artifact == other.artifact && parameters == other.parameters }

    static func register(_ name: String, exec: Reference, params: [Parameter] = []) -> Reference {
        register(name, Self(Reference(Self.self), artifact: exec, parameters: params), tags: ["command"])
    }
}
