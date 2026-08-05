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
            case .completed, .failed: return true
            default: return false
        }
    }
}

