import Foundation


struct Codec: @unchecked Sendable {
    let format: Format
    let encode: Encode
    let decode: Decode
    let encodeFrom: EncodeFrom

    public enum Format: String {
        case json
        case markdown
        case source
    }

    init(format: Format = .json, encode: @escaping Encode, decode: @escaping Decode, encodeFrom: @escaping EncodeFrom) {
        self.format = format
        self.encode = encode
        self.decode = decode
        self.encodeFrom = encodeFrom
    }

    var ext: String {
        switch format {
            case .json: return "json"
            case .markdown: return "md"
            case .source: return ""
        }
    }
}

struct StorableObject: Storable {
    var storageId: StorageId    
    var descriptor: Descriptor
    var value: any Resolvable

    init(descriptor: Descriptor, value: any Resolvable) {
        precondition(descriptor.origin.id == value.ref.id)
        precondition(descriptor.origin.typeId == value.ref.typeId)
        precondition(descriptor.origin.descriptorId == value.ref.descriptorId)
        precondition(descriptor.origin.contextId == value.ref.contextId)
        precondition(descriptor.origin.storageId == value.ref.storageId)
        precondition(descriptor.key == .descriptor(value.ref))
        self.storageId = value.ref.storageId
        self.descriptor = descriptor
        self.value = value
    }

    private enum Key: String, CodingKey { case storageId, descriptor, typeId, value }

    func encode(to encoder: Encoder) throws {
        guard storageId == value.ref.storageId,
              descriptor.origin.id == value.ref.id,
              descriptor.origin.typeId == value.ref.typeId,
              descriptor.origin.descriptorId == value.ref.descriptorId,
              descriptor.origin.contextId == value.ref.contextId,
              descriptor.origin.storageId == value.ref.storageId,
              descriptor.key == .descriptor(value.ref)
        else { throw RuntimeError.persistence(.encodingFailed(value.ref)) }

        var c = encoder.container(keyedBy: Key.self)
        try c.encode(storageId, forKey: .storageId)
        try c.encode(descriptor, forKey: .descriptor)
        try c.encode(value.ref.typeId, forKey: .typeId)
        let data = try JSONEncoder().encode(value)
        guard let property = Properties.load(data)?.property else {
            throw RuntimeError.persistence(.encodingFailed(value.ref))
        }
        try c.encode(property, forKey: .value)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        self.storageId = try c.decode(StorageId.self, forKey: .storageId)
        self.descriptor = try c.decode(Descriptor.self, forKey: .descriptor)
        let typeId = try c.decode(UUID.self, forKey: .typeId)

        guard let type = Runtime.shared.registry.typesByTypeId[typeId] else {
            throw RuntimeError.registry(.unregisteredType(typeId.uuidString))
        }

        let property = try c.decode(Property.self, forKey: .value)
        let data = try JSONEncoder().encode(property)
        self.value = try Self.decode(type, from: data)

        guard storageId == value.ref.storageId,
              typeId == value.ref.typeId,
              descriptor.origin.id == value.ref.id,
              descriptor.origin.descriptorId == value.ref.descriptorId,
              descriptor.origin.contextId == value.ref.contextId,
              descriptor.origin.storageId == value.ref.storageId,
              descriptor.key == .descriptor(value.ref)
        else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: c.codingPath,
                debugDescription: "Descriptor does not belong to decoded value."
            ))
        }
    }

    private static func decode(_ type: any Resolvable.Type, from data: Data) throws -> any Resolvable {
        func open<T: Resolvable>(_: T.Type) throws -> any Resolvable {
            try JSONDecoder().decode(T.self, from: data)
        }
        return try open(type)
    }
}

struct StorableCollection: Storable {
    var routes: [StorableObject]
    var closures: [StorableObject]
    var spaces: [StorableObject]
    var workspace: StorableObject
    var workspaces: [StorableObject]? = nil
}

struct PersistedObject<Value: Storable>: Sendable {
    let url: URL
    let value: Value
    let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}
