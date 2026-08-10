import Foundation


@Observable final class Composer: @unchecked Sendable {
    static let shared = Composer()
    private let contexts = Index<Context>()

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

    func start(_ ref: Reference) -> Composition? {
        guard compose(ref) != nil else { return nil }
        contexts.update(ref) { context in
            context.start { [weak self] signal, transcript in
                self?.contexts.update(ref) { $0.complete(signal, from: transcript) }
            }
        }
        return resolve(ref)
    }

    func stop(_ ref: Reference) -> Composition? {
        guard contexts.get(ref) != nil else { return nil }
        contexts.update(ref) { context in
            context.stop { [weak self] signal, transcript in
                self?.contexts.update(ref) { $0.complete(signal, from: transcript) }
            }
        }
        return resolve(ref)
    }

    func resolve() -> [Composition] { contexts.keys().compactMap { resolve($0) } }

    func resolve(_ ref: Reference) -> Composition? {
        guard contexts.get(ref)?.harness != nil else { return nil }
        return Composition(structure: ref)
    }
}
