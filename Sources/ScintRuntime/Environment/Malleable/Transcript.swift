import Foundation


struct Transcript: Malleable {
    let ref: Reference
    var origin: Reference
    private(set) var entries: Array<Entry> = []

    enum Entry: Codable, Sendable, Identifiable, Equatable {
        case event(ActivityId, Signal, Date)
        case material(Reference, Date)
        case value(String, Value, Date)
        case transcript(Key, Reference, Date)

        var id: AnyHashable {
            switch self {
                case .event(let id, _, _): id
                case .material(let ref, _): ref
                case .value(let key, _, let date): "\(key):\(date.timeIntervalSinceReferenceDate)"
                case .transcript(_, let ref, _): ref
            }
        }

        var created: Date {
            switch self {
                case .event(_, _, let date): date
                case .material(_, let date): date
                case .value(_, _, let date): date
                case .transcript(_, _, let date): date
            }
        }

        var terminal: Bool {
            if case .event(_, let signal, _) = self { return signal.terminal }
            return false
        }
    }

    init(_ ref: Reference = .init(Self.self)) {
        self.ref = ref
        self.origin = ref
    }

    var active: Bool { entries.last?.terminal != true }
    var started: Date? { entries.first?.created }
    var stopped: Date? { entries.last(where: \.terminal)?.created }

    var rendered: String {
        let lines = entries.map { entry -> String in
            let time = entry.created.formatted(date: .omitted, time: .standard)

            switch entry {
                case .event(_, let signal, _): return "\(time) \(signal.rendered)"
                case .material(let ref, _): return "\(time) material \(ref.descriptor.name)\n\(Runtime.shared.rendered(ref))"
                case .value(let key, let value, _): return "\(time) \(key) = \(value.rendered.joined(separator: " "))"
                case .transcript(let key, _, _): return "\(time) transcript \(key.ref.descriptor.name)"
            }
        }

        return (["\(ref.descriptor.name) (transcript)"] + lines).joined(separator: "\n")
    }

    mutating func insert(_ signal: Signal) {
        entries.append(.event(.init(), signal, .now))
    }

    mutating func insert(_ material: Reference) {
        if Material.with(material, { $0 }) != nil {
            entries.append(.material(material, .now))
        }
    }

    mutating func insert(_ key: String, _ value: Value) {
        entries.append(.value(key, value, .now))
    }

    mutating func insert(_ key: Key, _ transcript: Reference) {
        entries.append(.transcript(key, transcript, .now))
    }

    func output(_ key: String) -> Value? {
        entries.reversed().compactMap { entry -> Value? in
            guard case .value(let name, let value, _) = entry, name == key else { return nil }
            return value
        }.first
    }

    static func new(_ name: String, owner: Reference) -> Reference {
        guard owner.type == Space.self || owner.type == Workspace.self || owner.type == Transcript.self
        else { RuntimeError.fatal() }
        var instance = Self(.init(Self.self))
        instance.origin = owner
        Descriptor.new(instance.ref, name: name, tags: ["transcript"])
        Library.shared.store(for: instance.ref)?.add(instance.ref, instance)
        if owner.type == Workspace.self { guard let _ = Workspace.with(owner, { $0.add(instance.ref) })
        else { RuntimeError.fatal() } }
        else if owner.type == Space.self { guard let _ = Space.with(owner, { $0.add(instance.ref) })
        else { RuntimeError.fatal() } }
        return instance.ref
    }
}
