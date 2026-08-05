import Foundation


@Observable final class Composer:  Sendable {
    static let shared = Composer()
    private let contexts = Index<Context>()

    func context(_ ref: Reference) -> Context? { contexts.get(ref) }

    func compose(_ ref: Reference) -> Composition? {
        guard ref.type == Workspace.self || ref.type == Space.self else { return nil }
        if contexts.get(ref) == nil { contexts.set(ref, Context.compose(ref)) }
        return resolve(ref)
    }

    func resolve() -> [Composition] { contexts.keys().map(Composition(structure: ref)) }

    func resolve(_ ref: Reference? = nil) -> Composition? {
        guard contexts.get(ref) != nil else { return nil }
        return Composition(structure: ref)
    }
}
