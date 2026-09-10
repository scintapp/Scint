import Foundation


@Observable final class Index<Element: Keyed>: @unchecked Sendable {
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

        if let origin = refsByKey[newKey] {
            precondition(origin == ref, "Key '\(newKey)' points to Reference '\(origin).'")
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
