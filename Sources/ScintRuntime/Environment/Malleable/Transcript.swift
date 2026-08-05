import Foundation


public struct Transcript: Malleable {
    public let ref: Reference
    public var owner: Reference
    public private(set) var entries: [Entry] = []

    public enum Entry: Codable, Sendable, Identifiable {
        case signal(Signal, ActivityId, Date)
        case input(Reference, Date)
        case transcript(Reference, Key, Date)
        case property(String, Value, Date)

        public var id: AnyHashable {
            switch self {
                case .signal(_, let id, _): return id
                case .input(let ref, _): return ref
                case .transcript(let key, _, _): return key
                case .property(_, _, let date): return date
            }
        }

        public var created: Date {
            switch self {
                case .signal(_, _, let date): return date
                case .input(_, let date): return date
                case .transcript(_, _, let date): return date
                case .property(_, _, let date): return date
            }
        }

        public var terminal: Bool {
            if case .signal(let signal, _, _) = self { return signal.terminal }
            return false
        }
    }

    public init(_ ref: Reference = .init(Self.self)) {
        self.ref = ref
        self.owner = ref
    }

    public var active: Bool { entries.last?.terminal != true }
    public var started: Date? { entries.first?.created }
    public var stopped: Date? { entries.last(where: \.terminal)?.created }

    public var rendered: [String] {
        entries.map { entry in
            switch entry {
                case .signal(let signal, _, _): return signal.rendered
                case .input(let ref, _): return Sheet.with(ref, { $0.rendered }) ?? ""
                case .transcript(let ref, _, _): return ref.descriptor.name
                case .property(let key, let value, _): return "\(key)=\(value.rendered.joined(separator: " "))"
            }
        }
        .filter { !$0.isEmpty }
    }

    mutating func insert(_ signal: Signal) {
        entries.append(.signal(signal, .init(), .now))
    }

    mutating func insert(_ input: Reference) {
        guard let _ = Sheet.with(input, { $0 }) else { return }
        entries.append(.input(input, .now))
    }

    mutating func insert(_ transcript: Reference, _ key: Key) {
        entries.append(.transcript(transcript, key, .now))
    }

    mutating func insert(_ value: Value, for key: String) {
        entries.append(.property(key, value, .now))
    }

    func property(_ key: String) -> Value? {
        entries.reversed().compactMap { entry -> Value? in
            guard case .property(let name, let value, _) = entry, name == key else { return nil }
            return value
        }.first
    }

    static func new(_ name: String, owner: Reference) -> Reference {
        guard owner.type == Space.self || owner.type == Workspace.self else { RuntimeError.fatal() }
        var instance = Self(.init(Self.self))
        instance.owner = owner
        Descriptor.new(instance.ref, name: name, tags: ["transcript"])
        Library.shared.store(for: instance.ref)?.add(instance.ref, instance)
        if owner.type == Workspace.self { guard let _ = Workspace.with(owner, { $0.add(instance.ref) })
        else { RuntimeError.fatal() } }
        else { guard let _ = Space.with(owner, { $0.add(instance.ref) })
        else { RuntimeError.fatal() } }
        return instance.ref
    }
}
