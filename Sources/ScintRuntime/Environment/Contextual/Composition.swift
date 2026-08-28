import Foundation


struct Composition: Codable, Sendable {
    var space: Reference
    private var context: Context? { Composer.shared.context(space) }
    private var intents: [Intent] { context?.intents ?? [] }

    enum State: Codable, Sendable { case inactive, active, working }

    init(_ space: Reference) { self.space = space }

    var state: State {
        if intents.isEmpty { return .inactive }
        return intents.contains { !$0.observing } ? .working : .active
    }

    var closure: Reference {
        guard let closure = Space.with(space, { $0.closure })
        ?? Workspace.with(space, { $0.closure })
        else { RuntimeError.fatal() }
        return closure
    }

    var harness: Reference {
        guard let harness = Space.with(space, { $0.harness })
        ?? Workspace.with(space, { $0.harness })
        else { RuntimeError.fatal() }
        return harness
    }

    var config: Config { Closure.with(closure, { $0.config }) ?? [:] }
    var input: Reference { Closure.with(closure, { $0.input })! }
    var transcript: Reference { context?.transcript ?? space }
    var artifacts: [Reference] { Closure.with(closure, { $0 })?.artifacts ?? [] }
    var commands: [Reference] { Closure.with(closure, { $0 })?.commands ?? [] }
    var harnesses: [Reference] { Closure.with(closure, { $0 })?.harnesses ?? [] }
    var materials: [Reference] { Closure.with(closure, { $0 })?.materials ?? [] }
    var transcripts: [Reference] { Closure.with(closure, { $0 })?.transcripts ?? [] }
    var rendered: String { Closure.with(closure, { $0.rendered }) ?? "" }
}
