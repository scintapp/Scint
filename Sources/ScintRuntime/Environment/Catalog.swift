import Foundation


final class Catalog: Sendable {
    static let shared = Catalog()
    private let registry: Registry = Registry()
    private let descriptors: Index = Index<Descriptor>()
    func get(_ ref: Reference) -> Descriptor? { descriptors.get(ref) }
    func get(_ id: DescriptorId) -> Reference? { descriptors.ref(for: id) }
    func set(_ ref: Reference, _ descriptor: Descriptor) {
        precondition(descriptor.origin.id == ref.id, "Descriptor origin does not match its reference.")
        precondition(descriptor.origin.typeId == ref.typeId, "Descriptor origin does not match its reference.")
        precondition(descriptor.origin.descriptorId == ref.descriptorId, "Descriptor origin does not match its reference.")
        precondition(descriptor.origin.contextId == ref.contextId, "Descriptor origin does not match its reference.")
        precondition(descriptor.origin.storageId == ref.storageId, "Descriptor origin does not match its reference.")
        descriptors.set(ref, descriptor)
    }
    func keys() -> [Reference] { descriptors.keys() }
    func values() -> [Descriptor] { descriptors.values() }
    func with<R>(_ ref: Reference, _ body: (Descriptor) throws -> R) rethrows -> R? { try descriptors.with(ref, body) }
    func update<R>(_ ref: Reference, _ body: (inout Descriptor) throws -> R) rethrows -> R? {
        var updated = false
        let result = try descriptors.update(ref) { descriptor in
            let result = try body(&descriptor)
            updated = true
            return result
        }
        if updated { Task { await Coordinator.shared.schedule(ref) } }
        return result
    }
    @discardableResult func delete(_ ref: Reference) -> Descriptor? { descriptors.delete(ref) }
}
