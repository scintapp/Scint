import Foundation
import ScintRuntime


enum ComposeTool: Tool {
    enum Activity { case start, stop }
    enum Intent { case dispatch, evaluate, search }
    enum Verb: String, CaseIterable { case start, stop, read }

    static let method = Method(
        name: "compose",
        title: "Compose",
        description: "Runs spaces through their harness. start and stop a space's context. read returns a context's state, intent, harness, and transcript.",
        schema: .schema([
            "verb": .choice(Verb.self, "What to do."),
            "ref": .link("The space. Required to start or stop; read defaults to your space.")
        ], required: ["verb"])
    )

    static func compose(_ activity: Activity, for space: Reference) -> Context? {
        switch activity {
            case .start: Runtime.shared.start(space)
            case .stop: Runtime.shared.stop(space)
        }
    }

    static func context(for space: Reference) -> Context? {
        Runtime.shared.resolve(space)
    }

    static func read(_ context: Context?) throws -> Property {
        guard let context else { throw ToolError(message: "That space has no context. It needs a harness, and it has to be running to stop.") }
        return [
            "ref": .string(context.space.url?.absoluteString ?? context.space.descriptorId.uuidString.lowercased()),
            "state": .string(String(describing: context.state)),
            "intent": .string(context.intent.rawValue),
            "harness": .string(context.harness.descriptor.name),
        ]
    }

    static func call(_ arguments: [String: Property], in space: Reference) async throws -> Property {
        let verb = try arguments.choice("verb", Verb.self)
        if verb == .read { return try read(context(for: arguments.link("ref") ?? space)) }
        guard let target = try arguments.link("ref")
        else { throw ToolError(message: "ref is required to start or stop.") }
        return try read(compose(verb == .start ? .start : .stop, for: target))
    }
}

