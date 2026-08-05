import Foundation


final class Catalog: Sendable {
    public static let shared = Catalog()
    private let descriptors: Index = Index<Descriptor>()

    func keys() -> [Reference] { descriptors.keys() }
    func values() -> [Descriptor] { descriptors.values() }
    func get(_ ref: Reference) -> Descriptor? { descriptors.get(ref) }
    func set(_ ref: Reference, _ descriptor: Descriptor) { descriptors.set(ref, descriptor) }
    func with<R>(_ ref: Reference, _ body: (Descriptor) throws -> R) rethrows -> R? { try descriptors.with(ref, body) }
    @discardableResult func update<R>(_ ref: Reference, _ body: (inout Descriptor) throws -> R) rethrows -> R? {
        var updated: Bool = false
        let result = try descriptors.update(ref) { descriptor in
            descriptor.accessed = .now
            let result = try body(&descriptor)
            descriptor.updated = .now
            updated = true
            return result
        }
        if updated { Task { await Coordinator.shared.schedule(ref) } }
        return result
    }
    @discardableResult func delete(_ ref: Reference) -> Descriptor? { descriptors.delete(ref) }
}
