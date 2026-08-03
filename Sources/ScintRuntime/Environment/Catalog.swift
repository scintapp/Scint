import Foundation


public enum Framing: String, Codable, Sendable, CaseIterable {
    case Scint = "Scint"
    case composer = "composer"
    case editor = "editor"
    case library = "library"
    case studio = "studio"
}

public struct Descriptor: Keyable {
    public let key: Key
    public var origin: Reference
    public var framing: Framing
    public var name: String
    public var description: String
    public var tags: Set<String>
    public var created: Date
    public var updated: Date
    public var accessed: Date
    public var published: Bool

    public init(_ ref: Reference, _ name: String, _ framing: Framing = .Scint) {
        self.key = .descriptor(ref.descriptorId)
        self.origin = ref
        self.framing = framing
        self.name = name
        self.description = ""
        self.tags = []
        self.published = true
        self.created = .now
        self.updated = .now
        self.accessed = .now
    }

    public static func add(
        _ ref: Reference,
        framing: Framing? = .Scint,
        name: String,
        description: String? = "",
        tags: Set<String> = [],
        published: Bool = true
    ) {
        var instance = Self(ref, name, framing ?? .Scint)
        instance.name = name
        instance.description = description ?? ""
        instance.tags = tags
        instance.published = published
        Catalog.shared.set(ref, instance)
    }
}

final class Catalog: Sendable {
    public static let shared = Catalog()
    private let registry: Registry = Registry()
    private let descriptors: Index = Index<Descriptor>()

    func get(_ ref: Reference) -> Descriptor? { descriptors.get(ref) }
    func reference(for descriptor: DescriptorId) -> Reference? { descriptors.reference(for: .descriptor(descriptor)) }
    func set(_ ref: Reference, _ descriptor: Descriptor) {
        precondition(descriptor.origin.id == ref.id, "Descriptor origin does not match its reference.")
        precondition(descriptor.origin.typeId == ref.typeId, "Descriptor origin does not match its reference.")
        precondition(descriptor.origin.descriptorId == ref.descriptorId, "Descriptor origin does not match its reference.")
        precondition(descriptor.origin.contextId == ref.contextId, "Descriptor origin does not match its reference.")
        precondition(descriptor.origin.storageId == ref.storageId, "Descriptor origin does not match its reference.")
        precondition(descriptor.key == .descriptor(ref.descriptorId), "Descriptor key does not match its reference.")
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
