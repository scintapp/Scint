import Foundation


/// Starting a composable from outside.
///
/// The sibling of `open`: where that surfaces something to a person, this runs it. A trigger is an
/// automation primitive precisely because it is a URL — anything that can open one can drive a
/// space, and the runtime never learns which of them did. A schedule, a file watcher, a webhook, a
/// Shortcut, a finished run, a person clicking a chip: all the same door, and time is not a
/// privileged caller among them.
///
/// The parameters are the point. A harness already declares what it takes and in what shape, so a
/// query string has something to be validated against — including `.target`, which names the
/// runtime object a run is *about* rather than anything that reaches argv. An undeclared parameter
/// is refused rather than dropped, so a misspelled trigger fails loudly instead of quietly running
/// on defaults.
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

        // Settings land in the space's config, which is where a composition already reads them
        // from. A trigger parameterises the space, so what it supplies is what the next run uses
        // whether that run is triggered or started by hand.
        for (name, value) in try bind(parameters, against: declared) {
            if ref.type == Space.self { Space.with(ref, { $0.configure(value, for: name) }) }
            else { Workspace.with(ref, { $0.configure(value, for: name) }) }
        }

        guard Runtime.shared.start(ref) != nil else { throw CallbackError.dispatchFailed(ref) }
    }

    /// A query string is text; a harness parameter is typed. This is where the two meet — the
    /// declared `Value` is the template, and `construct` does the same validating it already does
    /// for config and for a tool call.
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

    /// Text into the grammar, before validation. Everything arrives as a string, so the declared
    /// shape is what says whether it names a runtime object — and a reference is written the way it
    /// is written everywhere else, as a `scint://` URL or a bare descriptor id.
    private static func read(_ text: String, as template: Value) -> Value {
        switch template {
            case .reference:
                guard let ref = ReferenceURL.reference(in: text) ?? ReferenceURL.resolve(text)
                        else { return .string(text) }
                return .reference(ref)

            // A single-element sequence or a single-key collection is a wrapper around the shape
            // that actually matters, and `construct` unwraps them the same way.
            case .sequence(let values) where values.count == 1:
                return read(text, as: values[0])

            case .collection(let values) where values.count == 1:
                return read(text, as: values.values.first!)

            default:
                return .string(text)
        }
    }
}
