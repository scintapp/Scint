import Foundation


struct Composition: Sendable {
    var space: Reference
    private var context: Context? { Composer.shared.context(space) }
    private var intents: [Intent] { context?.handlers.map { $0.intent } ?? [] }

    enum State: Sendable { case inactive, active, working, completed, failed }

    init(_ space: Reference) { self.space = space }

    var state: State {
        switch signal {
            case .failed: return .failed
            case .completed: return .completed
            default: break
        }

        if intents.isEmpty { return .inactive }
        return .working
    }

    private var signal: Signal? {
        return Transcript.with(transcript) { record -> Signal? in
            for entry in record.entries.reversed() {
                if case .event(let signal, _) = entry { return signal }
            }
            return nil
        } ?? nil
    }

    var closure: Reference {
        guard let closure = Space.with(space, { $0.closure })
        else { RuntimeError.fatal() }
        return closure
    }

    var harness: Reference {
        guard let ref = Space.with(space, { $0 })?.harness, let harness = Harness.with(ref, { $0 })
        else { RuntimeError.fatal() }
        return harness.ref
    }

    var intent: Intent {
        guard let intent = Harness.with(harness, { $0 })?.intent
        else { RuntimeError.fatal() }
        return intent
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

