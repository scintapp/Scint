import Foundation


struct Transcript: Malleable {
    let ref: Reference
    var origin: Reference
    private(set) var entries: Array<Entry> = []

    enum Entry: Codable, Sendable, Identifiable {
        case event(Signal, Date)
        case record(Chunk, Date)
        case transcript(Reference, Date)

        var id: AnyHashable {
            switch self {
                case .event(let signal, _): signal.id
                case .record(let chunk, _): chunk.key
                case .transcript(let ref, _): ref
            }
        }

        var created: Date {
            switch self {
                case .event(_, let date): date
                case .record(_, let date): date
                case .transcript(_, let date): date
            }
        }

        var terminal: Bool {
            if case .event(let signal, _) = self, case .completed = signal { return true }
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
                case .event(let signal, _):
                    return "\(time) \(signal.rendered)"
                case .record(let chunk, _):
                    return "\(time) \(chunk.name) = \(chunk.value.rendered.joined(separator: " "))"
                case .transcript(let ref, _):
                    return "\(time) transcript \(ref.descriptor.name)"
            }
        }

        return (["\(ref.descriptor.name) (transcript)"] + lines).joined(separator: "\n")
    }

    var branches: [Reference] {
        entries.compactMap { entry in
            guard case .transcript(let ref, _) = entry else { return nil }
            return ref
        }
    }

    var records: [Chunk] {
        entries.compactMap { entry in
            guard case .record(let chunk, _) = entry else { return nil }
            return chunk
        }
    }

    mutating func insert(_ signal: Signal) {
        entries.append(.event(signal, .now))
    }

    mutating func insert(_ chunk: Chunk) {
        entries.append(.record(chunk, .now))
    }

    mutating func insert(_ transcript: Reference) {
        guard transcript.type == Transcript.self else { return }
        entries.append(.transcript(transcript, .now))
    }

    func output(_ type: String) -> Chunk? {
        records.last { chunk in
            guard case .collection(let fields) = chunk.value,
                  case .string(let kind)? = fields["type"]
            else { return false }
            return kind == type
        }
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
