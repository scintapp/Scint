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

    init(_ ref: Reference = .init(Self.self)) {
        self.ref = ref
        self.artifact = ref
        self.parameters = []
    }

    init(_ ref: Reference, artifact: Reference, parameters: [Parameter]) {
        self.ref = ref
        self.artifact = artifact
        self.parameters = parameters
    }

    var rendered: String {
        var lines = ["\(ref.descriptor.name) (command)"]
        if !ref.descriptor.description.isEmpty { lines.append(ref.descriptor.description) }

        let usage = parameters.compactMap { parameter -> String? in
            switch parameter {
                case .argument(let name, let type, let required, _):
                    return required ? "\(name) \(type.described)" : "[\(name) \(type.described)]"
                case .fixed(let value): return value.rendered.joined(separator: " ")
                case .requirement: return nil
            }
        }.joined(separator: " ")

        let executable = Artifact.with(artifact, { $0.rendered }) ?? ""
        lines.append("usage: \(([executable] + [usage]).filter { !$0.isEmpty }.joined(separator: " "))")
        return lines.joined(separator: "\n")
    }

    func rendered(with values: [String: Value]) -> [String] {
        parameters.flatMap { parameter in
            switch parameter {
                case .argument(let name, _, _, let value): return (values[name] ?? value)?.rendered ?? []
                case .fixed(let value): return value.rendered
                case .requirement: return []
            }
        }
    }

    func dispatch(rendered arguments: [String], environment: [String: String] = [:], output: ((Signal) -> Void)? = nil) -> (pid: Int32, error: String?)? {
        guard let exec = Artifact.with(artifact, { $0.handler.executable }) ?? nil else { return nil }
        let result = Runtime.shared.services.start(exec, arguments: arguments, environment: environment)
        if let output, let pid = result?.pid, result?.error == nil { Runtime.shared.services.output(pid: pid, output) }
        return result
    }

    static func register(_ name: String, exec: Reference, params: [Parameter] = []) -> Reference {
        let ref = Reference(Self.self)
        let instance = Self(ref, artifact: exec, parameters: params)
        Descriptor.new(instance.ref, name: name, tags: ["command"])
        Library.shared.store(for: instance.ref)?.add(instance.ref, instance)
        return instance.ref
    }
}
