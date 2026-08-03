import Foundation
import OrderedCollections


typealias Encode = @Sendable (any Resolvable, JSONEncoder) throws -> Data
typealias Decode = @Sendable (Data, JSONDecoder) throws -> any Resolvable
typealias EncodeFrom = @Sendable (Bounding, Reference, JSONEncoder) throws -> Data?

public typealias Config = OrderedDictionary<String, Value>
public typealias ActivityId = UUID
public typealias ContextId = UUID
public typealias DescriptorId = UUID
public typealias StorageId = UUID
public typealias TypeId = UUID

protocol Storable: Codable & Sendable {}
protocol Storing: Sendable { func store(for ref: Reference?) -> Store? }
protocol Cataloging: Sendable { var entries: Library { get } }
protocol Persisting: Sendable { func encode<T: Resolvable>(_ type: T.Type) throws -> [StorableObject]; func decode(_ records: [StorableObject]) }
protocol Bounding: Sendable { func store(for ref: Reference?) -> Store?; var stores: [Store] { get } }
protocol Indexing: Sendable {}

protocol ExpressibleThings: ExpressibleByStringLiteral, ExpressibleByBooleanLiteral, ExpressibleByNilLiteral {}
protocol ExpressibleNumbers: ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {}
protocol Expressible: ExpressibleNumbers, ExpressibleThings {}
protocol Convertible: Sendable { var property: Property { get } }

@objc public protocol ServiceProviding {
    func start(_ command: String, _ arguments: [String], _ environment: [String: String], _ reply: @escaping (Int32, String?, String?) -> Void)
    func stop(pid: Int32, reply: @escaping (Bool) -> Void)
    func restart(pid: Int32, reply: @escaping (Int32, String?, String?) -> Void)
    func list(reply: @escaping ([String]) -> Void)
    func inspect(pid: Int32, reply: @escaping (String?) -> Void)
    func write(pid: Int32, input: String, close: Bool, reply: @escaping (String) -> Void)
    func ping(reply: @escaping (Bool) -> Void)
    func status(reply: @escaping (String) -> Void)
    func request(_ json: String, reply: @escaping (String) -> Void)
    func registerService(_ json: String, reply: @escaping (String) -> Void)
    func unregisterService(_ id: String, reply: @escaping (Bool) -> Void)
    func services(reply: @escaping (String) -> Void)
    func startService(_ id: String, reply: @escaping (String) -> Void)
    func stopService(_ id: String, reply: @escaping (Bool) -> Void)
    func restartService(_ id: String, reply: @escaping (String) -> Void)
}
@objc public protocol ServiceHandling { func handle(pid: Int32, chunk: String) }

public protocol Resolvable: Codable, Sendable { var ref: Reference { get } }
public protocol Keyable: Resolvable { var key: Key { get }; var origin: Reference { get } }
public protocol Composable: Resolvable { init(_ ref: Reference) }
public protocol Functional: Composable {}
public protocol Malleable: Composable { var owner: Reference { get set } }
public protocol Structural: Composable {}
public protocol Contextual: Keyable { init(_ origin: Reference); var transcript: Reference { get } }

extension Int: Convertible { public var property: Property { .integer(self) }}
extension Double: Convertible { public var property: Property { .decimal(self) }}
extension String: Convertible { public var property: Property { .string(self) }}
extension Bool: Convertible { public var property: Property { .bool(self) }}
extension Optional: Convertible where Wrapped: Convertible { var property: Property { self?.property ?? .null } }

extension Resolvable {
    public var name: String {
        get { Catalog.shared.with(ref, { $0.name }) ?? "" }
        set { Catalog.shared.update(ref, { $0.name = newValue }) }
    }

    public var description: String {
        get { Catalog.shared.with(ref, { $0.description }) ?? "" }
        set { Catalog.shared.update(ref, { $0.description = newValue }) }
    }

    public var tags: Set<String> {
        get { Catalog.shared.with(ref, { $0.tags }) ?? [] }
        set { Catalog.shared.update(ref, { $0.tags = newValue }) }
    }

    public var rendered: String { "" }

    @discardableResult public static func with<R>(_ ref: Reference,_ body: (Self) throws -> R) rethrows -> R? {
        if ref.type is any Structural.Type { return try Workspaces.shared.store(for: ref)?.with(ref, as: Self.self, body) }
        else { return try Library.shared.store(for: ref)?.with(ref, as: Self.self, body) }
    }

    @discardableResult public static func update<R>(_ ref: Reference,_ body: (inout Self) throws -> R) rethrows -> R? {
        if ref.type is any Structural.Type { return try Workspaces.shared.update(ref, as: Self.self, body) }
        else { return try Library.shared.store(for: ref)?.update(ref, as: Self.self, body) }
    }
}

extension Keyable {
    public var ref: Reference { origin }
}

extension Structural {
    public static func new(_ name: String, owner: Reference? = nil) -> Reference {
        var instance = Space(.init(Self.self))
        Descriptor.add(instance.ref, name: name, tags: [])
        instance.closure = Closure.new(name, owner: instance.ref)
        Workspaces.shared.add(instance.ref, instance)
        if let owner { Space.update(instance.ref) { $0.attach(to: owner) } }
        return instance.ref
    }
}

extension Contextual {
    static func compose(_ origin: Reference) -> Self { Self(origin) }
}

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
    func changed(_ ref: Reference) { Task { await Coordinator.shared.schedule(ref) } }

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
        else { throw RuntimeError.registry(.missingDescriptor(ref)) }
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
        try await Persistence.shared.write(PersistedObject(url: url, value: record))
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
