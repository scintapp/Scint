import Foundation


public struct Command: Functional {
    public let ref: Reference
    public let artifact: Reference
    public let parameters: [Parameter]

    public enum Parameter: Codable, Sendable, Equatable {
        case argument(name: String, type: Value, required: Bool = false, default: Value? = nil)
        case fixed(Value)
        case requirement(Value)
    }

    public init(_ ref: Reference = .init(Self.self)) {
        self.ref = ref
        self.artifact = ref
        self.parameters = []
    }

    init(_ ref: Reference, artifact: Reference, parameters: [Parameter]) {
        self.ref = ref
        self.artifact = artifact
        self.parameters = parameters
    }

    public var rendered: [String] { rendered(with: [:]) }

    public func rendered(with values: [String: Value]) -> [String] {
        parameters.flatMap { parameter in
            switch parameter {
                case .argument(let name, _, _, let value): return (values[name] ?? value)?.rendered ?? []
                case .fixed(let value): return value.rendered
                case .requirement: return []
            }
        }
    }

    public func dispatch(_ values: [String: Value] = [:], environment: [String: String] = [:], output: ((Signal) -> Void)? = nil) -> (pid: Int32, error: String?)? {
        return dispatch(rendered: rendered(with: values), environment: environment, output: output)
    }

    func dispatch(rendered arguments: [String], environment: [String: String] = [:], output: ((Signal) -> Void)? = nil) -> (pid: Int32, error: String?)? {
        guard let exec = Artifact.with(artifact, { $0.handler.executable }) ?? nil else { return nil }
        let result = Runtime.shared.services.start(exec, arguments: arguments, environment: environment)
        if let output, let pid = result?.pid, result?.error == nil { Runtime.shared.services.output(pid: pid, output) }
        return result
    }

    @discardableResult public static func register(_ name: String, exec: Reference, params: [Parameter] = []) -> Reference {
        let ref = Reference(Self.self)
        let instance = Self(ref, artifact: exec, parameters: params)
        Descriptor.add(instance.ref, name: name, tags: [])
        Library.shared.store(for: instance.ref)?.add(instance.ref, instance)
        return instance.ref
    }
}
