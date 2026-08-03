import Foundation


public struct Harness: Functional {
    public let ref: Reference
    public let intent: Intent
    public let command: Reference
    public let parameters: [Parameter]

    public enum Intent: Codable, Sendable, Equatable { case compose, dispatch, observe, execute, traverse }

    public enum Parameter: Codable, Sendable, Equatable {
        case argument(name: String, type: Value, required: Bool = false, default: Value? = nil)
        case command(content: String, value: Value? = nil)
        case dependency(name: String, type: Value, value: Value)
        case requirement(name: String, type: Value, value: Value)
        case target(name: String, type: Value, default: Value? = nil)
    }

    public init(_ ref: Reference = .init(Self.self)) {
        self.ref = ref
        self.command = ref
        self.intent = .compose
        self.parameters = []
    }

    init(_ ref: Reference, command: Reference, intent: Intent, parameters: [Parameter]) {
        self.ref = ref
        self.command = command
        self.intent = intent
        self.parameters = parameters
    }

    public var rendered: [String] { rendered(with: [:]) }

    public func rendered(with values: [String: Value]) -> [String] {
        parameters.flatMap { parameter in
            switch parameter {
                case .argument(let name, _, _, let value): return (values[name] ?? value)?.rendered ?? []
                case .command(let content, let value):
                    if value == .bool(false) { return [] }
                    if value == .bool(true) || value == nil { return content.isEmpty ? [] : [content] }
                    return (content.isEmpty ? [] : [content]) + (value?.rendered ?? [])
                case .dependency, .requirement, .target: return []
            }
        }
    }

    func arguments(with values: [String: Value]) -> [String] {
        let command = Command.with(command, { $0.rendered(with: values) }) ?? []
        return command + rendered(with: values)
    }

    public func run(_ values: [String: Value] = [:], environment: [String: String] = [:], output: @escaping (Signal) -> Void) -> (pid: Int32, error: String?)? {
        Command.with(command) { command in
            command.dispatch(rendered: arguments(with: values), environment: environment, output: output)
        } ?? nil
    }

    public func stop(pid: Int32) -> Bool {
        Runtime.shared.services.removeOutputHandler(pid: pid)
        return Runtime.shared.services.stop(pid: pid)
    }

    @discardableResult public static func register(_ name: String, command: Reference, intent: Intent, parameters: [Parameter] = []) -> Reference {
        let ref = Reference(Self.self)
        let instance = Self(ref, command: command, intent: intent, parameters: parameters)
        Descriptor.add(instance.ref, name: name, tags: [])
        Library.shared.store(for: instance.ref)?.add(instance.ref, instance)
        return instance.ref
    }
}
