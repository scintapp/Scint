import Foundation


enum Key: Codable, Sendable, Identifiable, Hashable {
    case branch(UUID, Reference)
    case context(Reference)
    case descriptor(Reference)

    var id: UUID {
        switch self {
            // A branch's identity is its own. Returning the owner's collapsed every chunk on a
            // reference to one id — latent while `Hashable` synthesises over the whole case, but
            // `id` is the accessor that addressing a chunk would reach for first. `ref` below
            // already answers "which object does this hang off".
            case .branch(let id, _): return id
            case .context(let ref): return ref.contextId
            case .descriptor(let ref): return ref.descriptorId
        }
    }

    var ref: Reference {
        switch self {
            case .branch(_, let ref): return ref
            case .context(let ref): return ref
            case .descriptor(let ref): return ref
        }
    }
}

struct Reference: Codable, Sendable, Identifiable, Hashable {
    let id: UUID
    let typeId: TypeId
    let contextId: ContextId
    let descriptorId: DescriptorId
    let storageId: StorageId

    static let handleLength = 8

    var handle: String {
        String(storageId.uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(Self.handleLength))
    }

    init(_ type: Resolvable.Type, id: UUID = UUID(), descriptorId: DescriptorId? = nil, contextId: ContextId? = nil, storageId: StorageId? = nil) {
        self.id = id
        self.typeId = .typeId(type.self)
        self.descriptorId = descriptorId ?? id
        self.storageId = storageId ?? id
        self.contextId = contextId ?? id
    }

    init(id: UUID, typeId: UUID, descriptorId: DescriptorId? = nil, contextId: ContextId? = nil, storageId: StorageId? = nil) {
        self.id = id
        self.typeId = typeId
        self.descriptorId = descriptorId ?? id
        self.contextId = contextId ?? id
        self.storageId = storageId ?? id
    }

    var type: Resolvable.Type? { Runtime.shared.registry.resolve(self) }
    var context: Composition? { Composer.shared.resolve(self) }
    var descriptor: Descriptor { Runtime.shared.get(self) }

    func delete() async throws {
        switch type {
            case is any Structural.Type: try await Workspaces.shared.delete(self)
            case is any Malleable.Type, is any Functional.Type: try await Library.shared.delete(self)
            default: throw RuntimeError.error("No store found.")
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(typeId)
        hasher.combine(descriptorId)
    }

    static func == (lhs: Reference, rhs: Reference) -> Bool {
        lhs.typeId == rhs.typeId
        && lhs.descriptorId == rhs.descriptorId
        && lhs.id == rhs.id
    }
}

