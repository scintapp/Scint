import Foundation


enum Signal: Codable, Sendable, Equatable {
    case composed(Reference)
    case started(Reference, Intent, Value)
    case updated(Reference, Intent, Value)
    case completed(Reference, Intent, Value)
    case stopped(Reference, Value?)
    case failed(Reference, Intent, Value)

    enum Intent: Codable, Sendable, Equatable {
        case composing, dispatching, evaluating, observing, searching
    }

    var id: AnyHashable {
        switch self {
            case .composed(let ref): return ref
            case .started(let ref, _, _): return ref
            case .updated(let ref, _, _): return ref
            case .completed(let ref, _, _): return ref
            case .stopped(let ref, _): return ref
            case .failed(let ref, _, _): return ref
        }
    }

    var ref: Reference {
        switch self {
            case .composed(let ref): ref
            case .started(let ref, _, _), .updated(let ref, _, _),
                 .completed(let ref, _, _), .failed(let ref, _, _): ref
            case .stopped(let ref, _): ref
        }
    }

    var intent: Intent? {
        switch self {
            case .composed, .stopped: nil
            case .started(_, let intent, _), .updated(_, let intent, _),
                 .completed(_, let intent, _), .failed(_, let intent, _): intent
        }
    }

    var value: Value? {
        switch self {
            case .composed: nil
            case .stopped(_, let value): value
            case .started(_, _, let value), .updated(_, _, let value),
                 .completed(_, _, let value), .failed(_, _, let value): value
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
        value?.rendered.joined(separator: " ") ?? ref.descriptor.name
    }
}
