import Foundation


enum Signal: Codable, Sendable, Equatable {
    case started(Value)
    case composing(Value)
    case evaluating(Value)
    case dispatching(Value)
    case observing(Value)
    case searching(Value)
    case updated(Value)
    case stopped(Value)

    var terminal: Bool {
        if case .stopped = self { return true }
        return false
    }

    var rendered: String {
        switch self {
            case .started(let value): return value.rendered.joined(separator: " ")
            case .composing(let value): return value.rendered.joined(separator: " ")
            case .evaluating(let value): return value.rendered.joined(separator: " ")
            case .dispatching(let value): return value.rendered.joined(separator: " ")
            case .observing(let value): return value.rendered.joined(separator: " ")
            case .searching(let value): return value.rendered.joined(separator: " ")
            case .updated(let value): return value.rendered.joined(separator: " ")
            case .stopped(let value): return value.rendered.joined(separator: " ")
        }
    }
}
