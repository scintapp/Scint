import Foundation


@Observable final class Composer: @unchecked Sendable {
    static let shared = Composer()
    private let contexts = Index<Context>()

    @discardableResult
    func load(_ refs: [Reference]) -> [Composition] {
        refs.compactMap { compose($0) }
    }

    func compose(_ ref: Reference) -> Composition? {
        let harness: Reference?
        switch ref.type {
            case is Space.Type: harness = Space.with(ref, { $0 })?.harness
            default: return nil
        }

        guard let harness, Harness.with(harness, { $0 }) != nil else { return nil }
        if let resolved = resolve(ref) { return resolved }
        contexts.set(ref, Context.new(ref))
        return resolve(ref)
    }

    func context(_ ref: Reference) -> Context? {
        guard let context = contexts.get(ref) else { return nil }
        return context
    }

    func resolve(_ ref: Reference) -> Composition? {
        guard contexts.get(ref) != nil else { return nil }
        return Composition(ref)
    }

    func resolve() -> [Composition] {
        contexts.keys().compactMap { resolve($0) }
    }

    func transmit(_ signal: Signal) -> Composition? {
        guard let composition = resolve(signal.ref) else { return nil }
        update(signal.ref) { context in context.handle(signal) }
        return composition
    }

    @discardableResult
    func update<R>(_ ref: Reference, _ body: (inout Context) throws -> R) rethrows -> R? {
        try contexts.update(ref, body)
    }
}

