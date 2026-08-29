import Foundation


@Observable final class Composer: @unchecked Sendable {
    static let shared = Composer()
    private let contexts = Index<Context>()
    private var listeners: [@Sendable (Reference, Signal) -> Void] = []

    @discardableResult
    func load(_ refs: [Reference]) -> [Composition] {
        refs.compactMap { compose($0) }
    }

    func context(_ ref: Reference) -> Context? { contexts.get(ref) }

    func compose(_ ref: Reference) -> Composition? {
        guard ref.type == Workspace.self || ref.type == Space.self else { return nil }
        if contexts.get(ref) == nil {
            let context = Context.new(ref)
            guard context.harness != nil else { return nil }
            contexts.set(ref, context)
        }
        return resolve(ref)
    }

    @discardableResult
    func update<R>(_ ref: Reference, _ body: (inout Context) throws -> R) rethrows -> R? {
        try contexts.update(ref, body)
    }

    func resolve() -> [Composition] { contexts.keys().compactMap { resolve($0) } }

    func resolve(_ ref: Reference) -> Composition? {
        guard contexts.get(ref)?.harness != nil else { return nil }
        return Composition(ref)
    }

    func onTerminal(_ listener: @escaping @Sendable (Reference, Signal) -> Void) {
        listeners.append(listener)
    }

    func announce(_ ref: Reference, _ signal: Signal) {
        guard signal.terminal else { return }
        for listener in listeners { listener(ref, signal) }
    }
}
