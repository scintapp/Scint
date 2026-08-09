import Foundation


@Observable final class Composer: @unchecked Sendable {
    static let shared = Composer()
    private let contexts = Index<Context>()

    func context(_ ref: Reference) -> Context? { contexts.get(ref) }

    func compose(_ ref: Reference) -> Composition? {
        guard ref.type == Workspace.self || ref.type == Space.self else { return nil }
        guard Context.harness(for: ref) != nil else { return nil }
        if contexts.get(ref) == nil { contexts.set(ref, Context.new(ref)) }
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
        contexts.update(ref) { $0.stop() }
        return resolve(ref)
    }

    func resolve() -> [Composition] { contexts.keys().compactMap { resolve($0) } }

    func resolve(_ ref: Reference) -> Composition? {
        guard contexts.get(ref) != nil, Context.harness(for: ref) != nil else { return nil }
        return Composition(structure: ref)
    }
}
