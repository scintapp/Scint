import Foundation



enum Intent: CaseIterable, Codable, Sendable {
    case compose
    case dispatch
    case observe
    case evaluate
    case search

    var rawValue: String { String(describing: self) }
}

enum Signal: Codable, Sendable, Equatable {
    case composed(Reference)
    case started(Reference, Value)
    case updated(Reference, Value)
    case completed(Reference, Value)
    case stopped(Reference, Value?)
    case failed(Reference, Value)
}

extension Signal {
    var ref: Reference {
        switch self {
            case .composed(let ref): ref
            case .started(let ref, _), .updated(let ref, _),
                 .completed(let ref, _), .failed(let ref, _), .stopped(let ref, _): ref
        }
    }

    var value: Value? {
        switch self {
            case .composed: nil
            case .stopped(_, let value): value
            case .started(_, let value), .updated(_, let value),
                 .completed(_, let value), .failed(_, let value): value
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
        value?.rendered
            .joined(separator: " ") ?? ref.descriptor.name
    }
}
