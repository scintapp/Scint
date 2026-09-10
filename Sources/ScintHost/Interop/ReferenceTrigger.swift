import Foundation


@MainActor enum ReferenceTrigger {
    static let action = "trigger"

    static func handle(_ request: ReferenceRouter.Request) -> Bool {
        guard let ref = request.reference else { return false }
        do {
            try start(ref, with: request.parameters)
            return true
        } catch {
            NSLog("Scint: trigger failed for \(ref.descriptorId): \(String(describing: error))")
            return false
        }
    }

    static func start(_ ref: Reference, with parameters: [String: String]) throws {
        guard ref.type == Space.self || ref.type == Workspace.self,
              let harness = (Space.with(ref, { $0.harness }) ?? Workspace.with(ref, { $0.harness })) ?? nil
                else { throw CallbackError.invalidTrigger(ref) }

        let declared = Harness.with(harness, { $0.parameters }) ?? []

        for (name, value) in try bind(parameters, against: declared) {
            if ref.type == Space.self { Space.with(ref, { $0.configure(value, for: name) }) }
            else { Workspace.with(ref, { $0.configure(value, for: name) }) }
        }

        guard Runtime.shared.start(ref) != nil else { throw CallbackError.dispatchFailed(ref) }
    }

    private static func bind(_ parameters: [String: String], against declared: [Harness.Parameter]) throws -> [String: Value] {
        let templates = declared.reduce(into: [String: Value]()) { templates, parameter in
            switch parameter {
                case .argument(let name, let type, _, _): templates[name] = type
                case .requirement(let name, let type, _): templates[name] = type
                case .target(let name, let type, _): templates[name] = type
                case .command: break
            }
        }

        return try parameters.reduce(into: [String: Value]()) { values, entry in
            guard let template = templates[entry.key]
                    else { throw ParsingError.unexpectedArguments([entry.key]) }
            values[entry.key] = try template.construct(read(entry.value, as: template), name: entry.key)
        }
    }

    private static func read(_ text: String, as template: Value) -> Value {
        switch template {
            case .reference:
                guard let ref = Reference.Link.reference(in: text) ?? Reference.Link.resolve(text)
                        else { return .string(text) }
                return .reference(ref)

            case .sequence(let values) where values.count == 1:
                return read(text, as: values[0])

            case .collection(let values) where values.count == 1:
                return read(text, as: values.values.first!)

            default:
                return .string(text)
        }
    }
}
