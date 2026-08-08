import Foundation


@Observable final class Store: @unchecked Sendable {
    private var entries: [Reference: Resolvable] = [:]

    func keys() -> [Reference] { Array(entries.keys) }
    func values() -> [any Resolvable] { keys().compactMap { with($0, as: (any Resolvable).self, { $0 }) } }
    func all<T>() -> [Reference: T] { entries as! [Reference: T] }
    func all<T>(as type: T.Type) -> [(Reference, T)] { entries.compactMap { key, val in (val as? T).map { (key, $0) } } }
    func reset() { entries.removeAll() }

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
              descriptor.key == .descriptor(ref)
                else { fatalError(RuntimeError.Catalog.missingDescriptor(ref).description) }
        entries[ref] = value
    }

    func with<T, R>(_ ref: Reference, as type: T.Type = T.self, _ body: (T) throws -> R) rethrows -> R? {
        guard let value = entries[ref] as? T else { return nil }
        return try body(value)
    }

    @discardableResult func update<T, R>(_ ref: Reference, as type: T.Type = T.self, _ body: (inout T) throws -> R) rethrows -> R? {
        guard var value = entries[ref] as? T else { return nil }
        let result = try body(&value)
        entries[ref] = value as? Resolvable
        return result
    }

    @discardableResult func remove(_ key: Reference) -> (any Resolvable)? {
        entries.removeValue(forKey: key) ?? nil
    }
}

@Observable final class Index<Element: Keyable>: @unchecked Sendable {
    private var entries: [Reference: Element] = [:]
    private var refsById: [UUID: Reference] = [:]
    private var refsByKey: [Key: Reference] = [:]
    private var keysByRef: [Reference: Key] = [:]

    func ref(for id: UUID) -> Reference? { refsById[id] }
    func ref(for key: Key) -> Reference? { refsByKey[key] }
    func key(for ref: Reference) -> Key? { keysByRef[ref] }
    func keys() -> [Reference] { Array(entries.keys) }
    func values() -> [Element] { Array(entries.values) }
    func contains(_ ref: Reference) -> Bool { entries[ref] != nil }
    func contains(_ key: Key) -> Bool { refsByKey[key] != nil }
    func clear() { entries.removeAll(); refsByKey.removeAll(); keysByRef.removeAll() }

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
            precondition(owner == ref, "Key '\(newKey)' points to Reference '\(owner).'")
        }

        entries[ref] = value
        refsById[ref.descriptorId] = ref
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
}
