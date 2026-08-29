import Foundation

/// Temporary narration for the Contextual module. Scaffolding, not architecture —
/// delete this file and every `Trace.` call site once the flow is understood.
///
/// Filter the console with `[` to read the story, or with a single scope like
/// `[Serialization]` to follow one stage.

enum Trace {
    static func say(_ scope: String, _ message: String, indent: Int = 0) {
        print("[\(scope)] \(String(repeating: "  ", count: indent))\(message)")
    }
    static func name(_ ref: Reference) -> String { Catalog.shared.get(ref)?.name ?? "unnamed" }
    static func id(_ ref: Reference) -> String { String(ref.id.uuidString.prefix(8)).lowercased() }
    static func ref(_ value: Reference) -> String { "\"\(name(value))\" \(id(value))" }
    static func kind(_ value: Reference) -> String { value.type.map { "\($0)" } ?? "unresolved" }
}


struct Registration: @unchecked Sendable {
    let id: TypeId
    let type: Resolvable.Type
    let codec: Codec

    init(id: TypeId, type: Resolvable.Type, codec: Codec) {
        self.id = id
        self.type = type
        self.codec = codec
    }
}

struct Registry: Sendable {
    private(set) var types: [Resolvable.Type] = []
    private(set) var typesByTypeId: [UUID: Resolvable.Type] = [:]
    private(set) var entriesByTypeId: [UUID: Registration] = [:]
    private(set) var entriesByTypeName: [String: Registration] = [:]

    init() {
        register(Material.self)
        register(Transcript.self)
        register(Artifact.self)
        register(Command.self)
        register(Harness.self)
        register(Bridge.self)
        register(Closure.self)
        register(Space.self)
        register(Workspace.self)
    }

    mutating func register<T: Resolvable>(_ type: T.Type) {
        let entry = Registration(
            id: .typeId(T.self),
            type: T.self,
            codec: .init(
                encode: { value, encoder in
                    guard let typed = value as? T else { throw RuntimeError.Persistence.encodingFailed(value.ref) }
                    return try encoder.encode(typed)
                },
                decode: { data, decoder in try decoder.decode(T.self, from: data) },
                encodeFrom: { store, ref, encoder in try store.with(ref, as: T.self) { try encoder.encode($0) } }
            )
        )

        types.append(type)
        typesByTypeId[entry.id] = entry.type
        entriesByTypeId[entry.id] = entry
        entriesByTypeName[String(describing: entry.type)] = entry
    }

    func resolve(_ ref: Reference) -> Resolvable.Type? {
        if let entry = entriesByTypeId[ref.typeId] { return entry.type }
        return nil
    }
}
