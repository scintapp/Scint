import Foundation


public enum Key: Codable, Sendable, Identifiable, Hashable {
    case context(Reference)
    case descriptor(Reference)

    public var id: AnyHashable {
        switch self {
            case .context(let ref): return ref.contextId
            case .descriptor(let ref): return ref.descriptorId
        }
    }

    public var ref: Reference {
        switch self {
            case .context(let ref): return ref
            case .descriptor(let ref): return ref
        }
    }
}

public struct Reference: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    let typeId: TypeId
    let contextId: ContextId
    let descriptorId: DescriptorId
    let storageId: StorageId

    public init(_ type: Resolvable.Type, id: UUID = UUID(), descriptorId: DescriptorId? = nil, contextId: ContextId? = nil, storageId: StorageId? = nil) {
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

    public var type: Resolvable.Type? { Runtime.shared.registry.resolve(self) }
    public var context: Composition? { Composer.shared.resolve(self) }
    public var descriptor: Descriptor { Runtime.shared.get(self) }

    public func delete() async throws {
        switch type {
            case is any Structural.Type: try await Workspaces.shared.delete(self)
            case is any Malleable.Type, is any Functional.Type: try await Library.shared.delete(self)
            default: throw RuntimeError.error("No store found.")
        }
    }


    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(typeId)
        hasher.combine(descriptorId)
    }

    public static func == (lhs: Reference, rhs: Reference) -> Bool {
        lhs.typeId == rhs.typeId
        && lhs.descriptorId == rhs.descriptorId
        && lhs.id == rhs.id
    }
}


