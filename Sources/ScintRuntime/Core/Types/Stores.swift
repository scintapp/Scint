import Foundation


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
        precondition(descriptor.key == .descriptor(value.ref.descriptorId))
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
              descriptor.key == .descriptor(value.ref.descriptorId)
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
              descriptor.key == .descriptor(value.ref.descriptorId)
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

@Observable final class Store: Sendable {
    private var entries: [Reference: Resolvable] = [:]

    public func update<T, R>(_ ref: Reference, as type: T.Type = T.self, _ body: (inout T) throws -> R) rethrows -> R? {
        guard var value = entries[ref] as? T else { return nil }
        let result = try body(&value)
        entries[ref] = value as? Resolvable
        return result
    }

    @discardableResult public func with<T, R>(_ ref: Reference, as type: T.Type = T.self, _ body: (T) throws -> R) rethrows -> R? {
        guard let value = entries[ref] as? T else { return nil }
        return try body(value)
    }

    func add(_ ref: Reference, _ value: Resolvable) {
        precondition(ref.id == value.ref.id, "Store reference does not match value reference.")
        precondition(ref.typeId == value.ref.typeId, "Store reference does not match value reference.")
        precondition(ref.descriptorId == value.ref.descriptorId, "Store reference does not match value reference.")
        precondition(ref.contextId == value.ref.contextId, "Store reference does not match value reference.")
        precondition(ref.storageId == value.ref.storageId, "Store reference does not match value reference.")
        guard let descriptor = Catalog.shared.get(ref),
              descriptor.origin.id == ref.id,
              descriptor.origin.typeId == ref.typeId,
              descriptor.origin.descriptorId == ref.descriptorId,
              descriptor.origin.contextId == ref.contextId,
              descriptor.origin.storageId == ref.storageId,
              descriptor.key == .descriptor(ref.descriptorId)
        else { fatalError(RuntimeError.Registry.missingDescriptor(ref).description) }
        entries[ref] = value
    }

    func keys() -> [Reference] { Array(entries.keys) }
    func values() -> [any Resolvable] { keys().compactMap { with($0, as: (any Resolvable).self, { $0 }) } }
    func all<T>() -> [Reference: T] { entries as! [Reference: T] }
    func all<T>(as type: T.Type) -> [(Reference, T)] { entries.compactMap { key, val in (val as? T).map { (key, $0) } } }
    func reset() { entries.removeAll() }
    @discardableResult func remove(_ key: Reference) -> (any Resolvable)? { entries.removeValue(forKey: key) ?? nil }
}

@Observable final class Index<Element: Keyable>: Sendable {
    private var entries: [Reference: Element] = [:]
    private var refsByKey: [Key: Reference] = [:]
    private var keysByRef: [Reference: Key] = [:]

    func reference(for key: Key) -> Reference? { refsByKey[key] }
    func key(for ref: Reference) -> Key? { keysByRef[ref] }
    func contains(_ ref: Reference) -> Bool { entries[ref] != nil }
    func contains(key: Key) -> Bool { refsByKey[key] != nil }
    func keys() -> [Reference] { Array(entries.keys) }
    func values() -> [Element] { Array(entries.values) }

    func get(_ ref: Reference) -> Element? { entries[ref] }

    func get(_ key: Key) -> Element? {
        guard let ref = refsByKey[key] else { return nil }
        return entries[ref]
    }

    func set(_ ref: Reference, _ value: Element) {
        let newKey = value.key
        if let oldKey = keysByRef[ref], oldKey != newKey {
            assert(refsByKey[oldKey] == ref, "key index desync for \(oldKey)")
            refsByKey[oldKey] = nil
        }
        if let owner = refsByKey[newKey] {
            precondition(owner == ref, "Key \(newKey) already bound to a different Reference")
        }
        entries[ref] = value
        refsByKey[newKey] = ref
        keysByRef[ref] = newKey
    }

    func with<R>(_ ref: Reference, _ body: (Element) throws -> R) rethrows -> R? {
        guard let value = entries[ref] else { return nil }
        return try body(value)
    }

    @discardableResult func update<R>(_ ref: Reference, _ body: (inout Element) throws -> R) rethrows -> R? {
        guard var value = entries[ref] else { return nil }
        let result = try body(&value)
        set(ref, value)
        return result
    }

    @discardableResult func delete(_ ref: Reference) -> Element? {
        guard let removed = entries.removeValue(forKey: ref) else { return nil }
        if let key = keysByRef.removeValue(forKey: ref) {
            assert(refsByKey[key] == ref, "key index desync on delete for \(key)")
            refsByKey[key] = nil
        }
        return removed
    }

    @discardableResult func delete(_ key: Key) -> Element? {
        guard let ref = refsByKey[key] else { return nil }
        return delete(ref)
    }

    func clear() {
        entries.removeAll(); refsByKey.removeAll(); keysByRef.removeAll()
    }
}
