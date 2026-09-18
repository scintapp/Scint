import Foundation


struct Transcript: Malleable {
    let ref: Reference
    var origin: Reference
    private(set) var entries: Array<Entry> = []

    enum Entry: Codable, Sendable, Identifiable {
        case event(Signal, Date)
        case record(Join, Date)
        case transcript(Reference, Intent, Date)

        var id: AnyHashable {
            switch self {
                case .event(let signal, _): signal.ref
                case .record(let chunk, _): chunk.key
                case .transcript(let ref, _, _): ref
            }
        }

        var created: Date {
            switch self {
                case .event(_, let date): date
                case .record(_, let date): date
                case .transcript(_, _, let date): date
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
                    return "\(time) \(String(describing: signal.value))"
                case .record(let chunk, _):
                    return "\(time) \(chunk.name) = \(chunk.value.rendered.joined(separator: " "))"
                case .transcript(let ref, _, _):
                    return "\(time) transcript \(ref.descriptor.name)"
            }
        }

        return (["\(ref.descriptor.name) (transcript)"] + lines).joined(separator: "\n")
    }

    var branches: [Reference] {
        entries.compactMap { entry in
            guard case .transcript(let ref, _, _) = entry else { return nil }
            return ref
        }
    }

    var records: [Join] {
        entries.compactMap { entry in
            guard case .record(let chunk, _) = entry else { return nil }
            return chunk
        }
    }

    func output(_ type: String) -> Join? {
        records.last { chunk in
            guard case .collection(let fields) = chunk.value, case .string(let kind)? = fields["type"]
            else { return false }
            return kind == type
        }
    }

    mutating func insert(_ signal: Signal) {
        entries.append(.event(signal, .now))
    }

    mutating func insert(_ chunk: Join) {
        entries.append(.record(chunk, .now))
    }

    mutating func insert(_ transcript: Reference, intent: Intent) {
        guard transcript.type == Transcript.self else { return }
        entries.append(.transcript(transcript, intent, .now))
    }

    static func new(_ origin: Reference) -> Reference {
        guard origin.type == Space.self || origin.type == Transcript.self
        else { RuntimeError.fatal("Not a valid transcript origin.") }
        var instance = Self(.init(Self.self))
        instance.origin = origin
        Descriptor.new(instance.ref, name: "Context", tags: ["context"])
        Library.shared.store(for: instance.ref)?.add(instance.ref, instance)
        if origin.type == Space.self { guard let _ = Space.with(origin, { $0.add(instance.ref) })
        else { RuntimeError.fatal() } }
        return instance.ref
    }

    static func new(_ origin: Reference, intent: Intent) -> Reference {
        guard origin.type == Transcript.self else { RuntimeError.fatal("Not a valid transcript origin.") }
        var branch = Self(.init(Self.self))
        branch.origin = origin
        Descriptor.new(branch.ref, name: "\(intent.rawValue) Context", tags: ["context", "branch"], published: false)
        Library.shared.store(for: branch.ref)?.add(branch.ref, branch)
        return branch.ref
    }
}
