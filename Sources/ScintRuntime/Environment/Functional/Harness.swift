import Foundation


struct Harness: Functional {
    let ref: Reference
    let intent: Intent
    let command: Reference
    let parameters: [Parameter]

    enum Intent: Codable, Sendable, CaseIterable, Equatable {
        case compose, dispatch, observe, evaluate, search

        var signal: Signal.Intent {
            switch self {
                case .compose: .composing
                case .dispatch: .dispatching
                case .observe: .observing
                case .evaluate: .evaluating
                case .search: .searching
            }
        }
    }

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

    func bind(_ supplied: [String: Value]) throws -> [String: Value] {
        var parsed: [String: Value] = [:]
        var expected: Set<String> = []

        for parameter in parameters {
            switch parameter {
                case .argument(let name, let type, let required, let fallback):
                    expected.insert(name)
                    if let value = supplied[name] { parsed[name] = try type.construct(value, name: name) }
                    else if let fallback { parsed[name] = try type.construct(fallback, name: name) }
                    else if required { throw ParsingError.missingArgument(name) }

                case .requirement(let name, let type, let value):
                    expected.insert(name)
                    parsed[name] = try type.construct(supplied[name] ?? value, name: name)

                case .target(let name, let type, let fallback):
                    expected.insert(name)
                    if let value = supplied[name] { parsed[name] = try type.construct(value, name: name) }
                    else if let fallback { parsed[name] = try type.construct(fallback, name: name) }

                case .command:
                    break
            }
        }

        let unexpected = supplied.keys.filter { !expected.contains($0) }.sorted()
        guard unexpected.isEmpty else { throw ParsingError.unexpectedArguments(unexpected) }
        return parsed
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
