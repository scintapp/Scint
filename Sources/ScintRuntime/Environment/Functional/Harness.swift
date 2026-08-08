import Foundation


struct Harness: Functional {
    let ref: Reference
    let intent: Intent
    let command: Reference
    let parameters: [Parameter]

    enum Intent: Codable, Sendable, Equatable { case compose, dispatch, observe, execute, traverse }

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

    var rendered: [String] { rendered(with: [:]) }

    func rendered(with values: [String: Value]) -> [String] {
        parameters.flatMap { parameter in
            switch parameter {
                case .argument(let name, _, _, let value):
                    return (values[name] ?? value)?.rendered ?? []

                case .command(let content, let value):
                    if value == .bool(false) { return [] }
                    if value == .bool(true) || value == nil { return content.isEmpty ? [] : [content] }
                    return (content.isEmpty ? [] : [content]) + (value?.rendered ?? [])

                case .requirement, .target:
                    return []
            }
        }
    }

    func start(_ origin: Reference, transcript: Reference, output: @escaping (Signal) -> Void) throws -> (pid: Int32, error: String?)? {
        let values = try Parser.parse(origin, transcript: transcript, for: ref)
        let environment = ["SCINT_CONTEXT": origin.contextId.uuidString.lowercased()]
        return Command.with(command) { command in
            command.dispatch(rendered: command.rendered(with: values) + rendered(with: values), environment: environment, output: output)
        } ?? nil
    }

    func stop(pid: Int32) -> Bool {
        Runtime.shared.services.removeOutputHandler(pid: pid)
        return Runtime.shared.services.stop(pid: pid)
    }

    static func register(_ name: String, command: Reference, intent: Intent, parameters: [Parameter] = []) -> Reference {
        let instance = Self(.init(Self.self), command: command, intent: intent, params: parameters)
        Descriptor.new(instance.ref, name: name, tags: [])
        Library.shared.store(for: instance.ref)?.add(instance.ref, instance)
        return instance.ref
    }
}
