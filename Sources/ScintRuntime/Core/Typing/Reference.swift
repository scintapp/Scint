import Foundation


enum Key: Codable, Sendable, Identifiable, Hashable {
    case chunk(Reference)
    case context(Reference)
    case descriptor(Reference)

    var id: AnyHashable {
        switch self {
            case .chunk(let ref): return ref.id
            case .context(let ref): return ref.contextId
            case .descriptor(let ref): return ref.descriptorId
        }
    }

    var ref: Reference {
        switch self {
            case .chunk(let ref): return ref
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

