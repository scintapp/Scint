import Foundation


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

    public init() {
        register(Sheet.self)
        register(Transcript.self)
        register(Artifact.self)
        register(Command.self)
        register(Harness.self)
        register(Route.self)
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
                    guard let typed = value as? T else { throw RuntimeError.persistence(.encodingFailed(value.ref)) }
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
