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
