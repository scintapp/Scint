import Foundation


struct Descriptor: Keyed {
    var key: Key { .descriptor(origin) }
    var origin: Reference
    var name: String
    var description: String
    var created: Date
    var updated: Date
    var accessed: Date
    var published: Bool
    var tags: Set<String>

    init(_ ref: Reference, _ name: String) {
        self.origin = ref
        self.name = name
        self.description = ""
        self.tags = []
        self.published = true
        self.created = .now
        self.updated = .now
        self.accessed = .now
    }

    static func new(_ ref: Reference, name: String, description: String? = "", tags: Set<String> = [], published: Bool = true) {
        var instance = Self(ref, name)
        instance.name = name
        instance.description = description ?? ""
        instance.tags = tags
        instance.published = published
        Catalog.shared.set(ref, instance)
    }
}

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

    func with<R>(_ ref: Reference, _ body: (Descriptor) throws -> R) rethrows -> R? {
        try descriptors.with(ref, body)
    }

    func update<R>(_ ref: Reference, _ body: (inout Descriptor) throws -> R) rethrows -> R? {
        var updated = false
        let result = try descriptors.update(ref) { descriptor in
            let result = try body(&descriptor)
            descriptor.updated = .now
            updated = true
            return result
        }
        if updated { Task { await Coordinator.shared.updated(ref) } }
        return result
    }

    /// Stamps the descriptors of referenced objects with when they were last updated.
    func stamp(_ updates: [Reference: Date]) {
        for (ref, date) in updates {
            descriptors.update(ref) { $0.updated = max($0.updated, date) }
        }
    }

    @discardableResult
    func delete(_ ref: Reference) -> Descriptor? { descriptors.delete(ref) }
}
