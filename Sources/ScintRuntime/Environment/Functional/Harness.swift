import Foundation


struct Harness: Functional {
    let ref: Reference
    let intent: Intent
    let command: Reference
    let parameters: [Parameter]

    enum Intent: Codable, Sendable, Equatable { case compose, dispatch, observe, execute, search }

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
        if let name = Command.with(command, { _ in command.descriptor.name }) { lines.append("command: \(name)") }

        for parameter in parameters {
            switch parameter {
                case .argument(let name, let type, let required, let value):
                    var line = "\(name): \(type.described)"
                    if required { line += " (required)" }
                    else if let value { line += " (default \(value.rendered.joined(separator: " ")))" }
                    lines.append(line)

                case .requirement(let name, let type, let value):
                    lines.append("\(name): \(type.described) (fixed \(value.rendered.joined(separator: " ")))")

                case .target(let name, let type, _):
                    lines.append("\(name): \(type.described) (target)")

                case .command:
                    break
            }
        }

        return lines.joined(separator: "\n")
    }

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

    func stop(pid: Int32) -> Bool {
        Runtime.shared.services.removeOutputHandler(pid: pid)
        return Runtime.shared.services.stop(pid: pid)
    }

    static func register(_ name: String, command: Reference, intent: Intent, parameters: [Parameter] = []) -> Reference {
        let instance = Self(.init(Self.self), command: command, intent: intent, params: parameters)
        Descriptor.new(instance.ref, name: name, tags: ["harness"])
        Library.shared.store(for: instance.ref)?.add(instance.ref, instance)
        return instance.ref
    }
}
