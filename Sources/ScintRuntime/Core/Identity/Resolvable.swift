import Foundation
import CryptoKit


protocol Resolvable: Codable, Sendable { var ref: Reference { get } }
protocol Keyed: Resolvable { var key: Key { get } }

protocol Composable: Resolvable {}
protocol Functional: Composable { func matches(_ other: Self) -> Bool }
protocol Malleable: Composable { var origin: Reference { get set } }
protocol Structural: Composable { var closure: Reference { get } }
protocol Contextual: Keyed { var origin: Reference { get }; var transcript: Reference { get set } }

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
    static func exists<R: Resolvable>(_ name: String, as type: R.Type) -> Bool {
        Catalog.shared.values().map { $0.name }.filter { $0 == name }.first != nil
    }

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

extension Keyed { var ref: Reference { key.ref }; var id: Reference { ref } }

extension Structural {
    var artifacts: [Reference] { Closure.with(closure, { $0 })?.artifacts ?? [] }
    var commands: [Reference] { Closure.with(closure, { $0 })?.commands ?? [] }
    var harnesses: [Reference] { Closure.with(closure, { $0 })?.harnesses ?? [] }
    var materials: [Reference] { Closure.with(closure, { $0 })?.materials ?? [] }
    var transcripts: [Reference] { Closure.with(closure, { $0 })?.transcripts ?? [] }
    var directories: [Reference] { Closure.with(closure, { $0 })?.directories ?? [] }
    var sections: [Reference] { artifacts + commands + harnesses + materials + transcripts }
    var rendered: String { Closure.with(closure, { $0.rendered }) ?? "" }
    var config: Config { Closure.with(closure, { $0.config }) ?? [:] }
    var composition: Composition? { Composer.shared.compose(ref) }

    var input: Reference {
        guard let closure = Closure.with(closure, { $0 })
        else { RuntimeError.fatal() }
        return closure.input
    }

    func configure(_ value: Value?, for key: String) {
        Closure.update(closure) { $0.config[key] = value }
    }

    @discardableResult
    static func new(_ name: String, origin: Reference? = nil) -> Reference {
        var instance = Space(.init(Self.self))
        Descriptor.new(instance.ref, name: name, tags: [])
        instance.closure = Closure.new(name, origin: instance.ref)
        Workspaces.shared.add(instance.ref, instance)
        if let origin { Space.update(instance.ref) { $0.attach(to: origin) } }
        return instance.ref
    }
}

extension Functional {
    var id: AnyHashable { ref }

    /// Returns the interface already registered under this name when it's the same one. A
    /// different interface under a taken name registers with a number appended.
    static func register(_ name: String, _ instance: Self, tags: Set<String>) -> Reference {
        let registered = Runtime.shared.store(for: Reference(Self.self))?.all(as: Self.self) ?? []

        func variant(_ candidate: String) -> Bool {
            guard candidate != name else { return true }
            let prefix = "\(name) "
            return candidate.hasPrefix(prefix) && Int(candidate.dropFirst(prefix.count)) != nil
        }

        if let (ref, _) = registered.first(where: { variant($0.0.descriptor.name) && $0.1.matches(instance) }) {
            return ref
        }

        let taken = Set(registered.map { $0.0.descriptor.name })
        var unique = name
        var suffix = 2
        while taken.contains(unique) {
            unique = "\(name) \(suffix)"
            suffix += 1
        }

        Descriptor.new(instance.ref, name: unique, tags: tags)
        Library.shared.store(for: instance.ref)?.add(instance.ref, instance)
        return instance.ref
    }
}

extension Contextual { var origin: Reference { key.ref } }

extension UUID {
    static func typeId(_ type: Any.Type) -> TypeId {
        let fullyQualifiedName = String(reflecting: type)
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
