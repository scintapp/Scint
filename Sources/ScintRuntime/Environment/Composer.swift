import Foundation


public struct Composition: Codable, Sendable {
    public let root: Reference
    public var harness: Reference? { context?.harness?.ref }
    public var transcript: Reference { context?.transcript ?? root }

    public var intentTranscript: Reference? {
        if let transcript = context?.intents.last?.transcript { return transcript }
        return Transcript.with(transcript, { $0.entries }).flatMap { entries in
            entries.reversed().compactMap { entry -> Reference? in
                guard case .transcript(let ref, _, _) = entry else { return nil }
                return ref
            }.first
        }
    }

    public var state: State {
        guard let context else { return .inactive }
        if !context.intents.isEmpty { return .running }
        guard let signal = Transcript.with(context.transcript, { transcript in
            transcript.entries.reversed().compactMap { entry -> Signal? in
                guard case .signal(let signal, _, _) = entry else { return nil }
                return signal
            }.first
        }) ?? nil else { return .active }

        switch signal {
            case .completed: return .completed
            case .failed: return .failed
            case .eval, .started, .updated: return .active
        }
    }

    var context: Context? { Composer.shared.context(root) }
    var intents: [Context.Intent] { context?.intents ?? [] }

    public enum State: Codable, Sendable, Equatable { case inactive, active, running, completed, failed }

    init(_ root: Reference) { self.root = root }
}

@Observable final class Composer: @unchecked Sendable {
    static let shared = Composer()
    private let contexts = Index<Context>()

    func context(_ ref: Reference) -> Context? { contexts.get(ref) }

    func compose(_ signal: Signal) -> Composition? {
        guard case .eval(let origin) = signal else { return nil }
        guard contexts.get(origin) != nil || compose(origin) != nil else { return nil }
        contexts.update(origin) { $0.compose(signal) }
        return resolve(origin)
    }

    @discardableResult func compose(_ ref: Reference) -> Composition? {
        guard ref.type == Workspace.self || ref.type == Space.self else { return nil }
        if contexts.get(ref) == nil { contexts.set(ref, Context.compose(ref)) }
        return resolve(ref)
    }

    func receive(_ signal: Signal, origin: Reference, transcript: Reference) {
        contexts.update(origin) { $0.receive(signal, from: transcript) }
    }

    func changed(_ ref: Reference) {
        for origin in contexts.keys() { contexts.update(origin) { $0.observe(ref) } }
    }

    func resolve() -> [Composition] { contexts.keys().map(Composition.init) }

    func resolve(_ ref: Reference) -> Composition? {
        guard contexts.get(ref) != nil else { return nil }
        return Composition(ref)
    }
}
