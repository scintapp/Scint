import Foundation
import OrderedCollections


typealias Encode = @Sendable (any Resolvable, JSONEncoder) throws -> Data
typealias Decode = @Sendable (Data, JSONDecoder) throws -> any Resolvable
typealias EncodeFrom = @Sendable (Bounding, Reference, JSONEncoder) throws -> Data?

typealias Config = OrderedDictionary<String, Value>

protocol Storable: Codable & Sendable {}
protocol Bounding: Sendable { func store(for ref: Reference?) -> Store?; var stores: [Store] { get } }
protocol Storing: Sendable { func store(for ref: Reference?) -> Store? }

extension Bounding {
    func add(_ ref: Reference, _ value: Resolvable) {
        guard let store = store(for: ref) else { return }
        store.add(ref, value)
        changed(ref)
    }

    func remove(_ ref: Reference) {
        guard let store = store(for: ref), store.remove(ref) != nil else { return }
        changed(ref)
    }

    func all<T: Resolvable>(as type: T.Type) -> [(Reference, T)] { store(for: Reference(T.self))?.all(as: type) ?? [] }

    func changed(_ ref: Reference) { Task { await Coordinator.shared.updated(ref) } }

    func with<T: Resolvable, R>(_ ref: Reference, as type: T.Type = T.self, _ body: (T) throws -> R) rethrows -> R? {
        try store(for: ref)?.with(ref, as: type, body)
    }

    func update<T: Resolvable, R>(_ ref: Reference, as type: T.Type = T.self, _ body: (inout T) throws -> R) rethrows -> R? {
        guard let store = store(for: ref) else { return nil }
        var updated = false
        let result = try store.update(ref, as: type) { value in
            let result = try body(&value)
            updated = true
            return result
        }
        if updated { changed(ref) }
        return result
    }

    func record(for ref: Reference) throws -> StorableObject? {
        guard let value = store(for: ref)?.with(ref, as: (any Resolvable).self, { $0 }) else { return nil }
        guard let descriptor = Catalog.shared.get(ref)
                else { throw RuntimeError.Catalog.missingDescriptor(ref) }
        return StorableObject(descriptor: descriptor, value: value)
    }

    func records() throws -> [StorableObject] {
        try stores.flatMap { store in
            try store.values().map { value in
                guard let record = try record(for: value.ref)
                        else { throw RuntimeError.persistence(.encodingFailed(value.ref)) }
                return record
            }
        }
    }

    func encode(for ref: Reference) async throws {
        guard let record = try record(for: ref) else { return }
        let url = Runtime.shared.settings.persistence.libraryPath(for: ref)
        try await Persistence.shared.write(PersistableObject(url: url, value: record))
    }

    func decode(_ records: [StorableObject]) {
        for record in records {
            Catalog.shared.set(record.value.ref, record.descriptor)
            store(for: record.value.ref)?.add(record.value.ref, record.value)
        }
    }
}

extension Storing {
    func add(_ ref: Reference, _ value: Resolvable) { store(for: ref)?.add(ref, value) }
    func remove(_ ref: Reference) { store(for: ref)?.remove(ref) }
    func all<T: Resolvable>(as type: T.Type) -> [(Reference, T)] { store(for: Reference(T.self))?.all(as: type) ?? [] }

    func with<T: Resolvable, R>(_ ref: Reference, as type: T.Type = T.self, _ body: (T) throws -> R) rethrows -> R? {
        try store(for: ref)?.with(ref, as: type, body)
    }

    func update<T: Resolvable, R>(_ ref: Reference, as type: T.Type = T.self, _ body: (inout T) throws -> R) rethrows -> R? {
        try store(for: ref)?.update(ref, as: type, body)
    }
}

struct Codec: @unchecked Sendable {
    let format: Format
    let encode: Encode
    let decode: Decode
    let encodeFrom: EncodeFrom

    enum Format: String { case json, markdown, source }

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
            throw RuntimeError.Persistence.unregisteredType(typeId.uuidString)
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

struct StorableStructure: Storable {
    var bridges: [StorableObject]
    var closures: [StorableObject]
    var spaces: [StorableObject]
}

struct StorableInterface: Storable {
    var harness: StorableObject
    var commands: [StorableObject]
    var artifacts: [StorableObject]
}

struct StorableBundle: Storable {
    var structure: StorableStructure
    var harnesses: [StorableInterface]
    var materials: [StorableObject]
}

struct PersistableObject<Value: Storable>: Sendable {
    let url: URL
    let value: Value
    let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}
