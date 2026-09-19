import Foundation


struct Join: Keyed {
    let key: Key
    let origin: Reference
    let value: Value

    init(_ ref: Reference, _ origin: Reference, _ value: Value) {
        self.key = .mapping(.init(), ref)
        self.origin = origin
        self.value = value
    }
}

enum Signal: Codable, Sendable, Equatable {
    case composed(Value)
    case started(Value)
    case updated(Value)
    case completed(Value)
    case stopped(Value)
    case failed(Value)
}

extension Signal {
    var value: Value {
        switch self {
            case .composed(let value), .started(let value), .updated(let value),
                 .completed(let value), .stopped(let value), .failed(let value): value
        }
    }

    var ref: Reference? {
        switch value {
            case .reference(let ref): ref
            case .collection(let fields): if case .reference(let ref)? = fields["ref"] { ref } else { nil }
            default: nil
        }
    }

    var terminal: Bool {
        switch self {
            case .completed, .stopped, .failed: true
            case .composed, .started, .updated: false
        }
    }

    var failed: Bool {
        if case .failed = self { return true }
        return false
    }

    var rendered: String {
        if case .collection(let fields) = value, let text = fields["text"] { return text.rendered.joined(separator: " ") }
        return ref?.descriptor.name ?? value.rendered.joined(separator: " ")
    }
}

extension Signal {
    private enum CodingKeys: String, CodingKey, CaseIterable { case composed, started, updated, completed, stopped, failed }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let key = try c.tag()
        let value = try c.decode(Value.self, forKey: key)
        switch key {
            case .composed: self = .composed(value)
            case .started: self = .started(value)
            case .updated: self = .updated(value)
            case .completed: self = .completed(value)
            case .stopped: self = .stopped(value)
            case .failed: self = .failed(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        let key: CodingKeys = switch self {
            case .composed: .composed
            case .started: .started
            case .updated: .updated
            case .completed: .completed
            case .stopped: .stopped
            case .failed: .failed
        }
        try c.encode(value, forKey: key)
    }
}
