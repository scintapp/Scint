import Foundation


public enum Signal: Codable, Sendable, Equatable {
    case eval(Reference)
    case started(Reference)
    case updated(Value)
    case completed
    case failed(Value)

    public var terminal: Bool {
        switch self {
            case .completed, .failed: return true
            default: return false
        }
    }

    public var rendered: String {
        switch self {
            case .eval: return "trigger"
            case .started(let ref): return "started \(ref.descriptor.name)"
            case .updated(let value): return value.rendered.joined(separator: " ")
            case .completed: return "completed"
            case .failed(let value): return value.rendered.joined(separator: " ")
        }
    }
}
