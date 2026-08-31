import Foundation
import CryptoKit


extension Int: Convertible { var property: Property { .integer(self) }}
extension Double: Convertible { var property: Property { .decimal(self) }}
extension String: Convertible { var property: Property { .string(self) }}
extension Bool: Convertible { var property: Property { .bool(self) }}
extension Optional: Convertible where Wrapped: Convertible { var property: Property { self?.property ?? .null } }

extension Resolvable {
    var name: String {
        get { Catalog.shared.with(ref, { $0.name }) ?? "" }
        set { Catalog.shared.update(ref, { $0.name = newValue }) }
    }

    var description: String {
        get { Catalog.shared.with(ref, { $0.description }) ?? "" }
        set { Catalog.shared.update(ref, { $0.description = newValue }) }
    }

    var tags: Set<String> {
        get { Catalog.shared.with(ref, { $0.tags }) ?? [] }
        set { Catalog.shared.update(ref, { $0.tags = newValue }) }
    }

    var rendered: String { "" }

    @discardableResult
    static func with<R>(_ ref: Reference,_ body: (Self) throws -> R) rethrows -> R? {
        if ref.type is any Structural.Type { try Workspaces.shared.store(for: ref)?.with(ref, as: Self.self, body) }
        else { try Library.shared.store(for: ref)?.with(ref, as: Self.self, body) }
    }

    @discardableResult
    static func update<R>(_ ref: Reference,_ body: (inout Self) throws -> R) rethrows -> R? {
        if ref.type is any Structural.Type { try Workspaces.shared.store(for: ref)?.update(ref, as: Self.self, body) }
        else { try Library.shared.store(for: ref)?.update(ref, as: Self.self, body) }
    }
}

extension Keyable { var ref: Reference { key.ref } }

extension Structural {
    var composition: Composition? { Composer.shared.resolve(ref) }
    var artifacts: [Reference] { Closure.with(closure, { $0 })?.artifacts ?? [] }
    var commands: [Reference] { Closure.with(closure, { $0 })?.commands ?? [] }
    var harnesses: [Reference] { Closure.with(closure, { $0 })?.harnesses ?? [] }
    var materials: [Reference] { Closure.with(closure, { $0 })?.materials ?? [] }
    var transcripts: [Reference] { Closure.with(closure, { $0 })?.transcripts ?? [] }
    var directories: [Reference] { Closure.with(closure, { $0 })?.directories ?? [] }
    var sections: [Reference] { artifacts + commands + harnesses + materials + transcripts }
    var rendered: String { Closure.with(closure, { $0.rendered }) ?? "" }
    var config: Config { Closure.with(closure, { $0.config }) ?? [:] }

    static func new(_ name: String, origin: Reference? = nil) -> Reference {
        var instance = Space(.init(Self.self))
        Descriptor.new(instance.ref, name: name, tags: [])
        instance.closure = Closure.new(name, owner: instance.ref)
        Workspaces.shared.add(instance.ref, instance)
        if let origin { Space.update(instance.ref) { $0.attach(to: origin) } }
        return instance.ref
    }
}

extension Contextual {
    @discardableResult
    static func with<R>(_ ref: Reference, _ body: (Context) throws -> R) rethrows -> R? {
        try Composer.shared.context(ref).map(body)
    }

    @discardableResult
    static func update<R>(_ ref: Reference, _ body: (inout Context) throws -> R) rethrows -> R? {
        try Composer.shared.update(ref, body)
    }
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

extension UUID {
    static func typeId(_ type: Any.Type) -> TypeId { deterministicTypeId(String(reflecting: type)) }

    static func deterministicTypeId(_ fullyQualifiedName: String) -> UUID {
        let data = Data(fullyQualifiedName.utf8)
        let digest = SHA256.hash(data: data)
        let bytes = [UInt8](digest)

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2],
            bytes[3], bytes[4], bytes[5],
            (bytes[6] & 0x0F) | 0x50, bytes[7],
            (bytes[8] & 0x3F) | 0x80, bytes[9],
            bytes[10], bytes[11], bytes[12],
            bytes[13], bytes[14], bytes[15]
        ))
    }
}

extension String {
    var normalized: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .map { $0.isLetter || $0.isNumber ? String($0).lowercased() : " " }
            .joined()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    var tokenized: [String] {
        normalized
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }
}
