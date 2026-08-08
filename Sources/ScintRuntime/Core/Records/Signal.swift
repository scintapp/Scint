import Foundation


enum Signal: Codable, Sendable, Equatable {
    case composed(Reference)
    case started(Reference)
    case stopped(Reference)
    case updated(Value)
    case completed(Value?)
    case failed(Value)

    var terminal: Bool {
        switch self {
            case .stopped, .completed, .failed: return true
            default: return false
        }
    }

    var rendered: String {
        switch self {
            case .composed(let ref): return "composed \(ref.descriptor.name)"
            case .started(let ref): return "started \(ref.descriptor.name)"
            case .stopped(let ref): return "stopped \(ref.descriptor.name)"
            case .updated(let value): return value.rendered.joined(separator: " ")
            case .completed(let value): return value?.rendered.joined(separator: " ") ?? "completed"
            case .failed(let value): return value.rendered.joined(separator: " ")
        }
    }
}
