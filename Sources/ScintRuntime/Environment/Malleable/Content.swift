import Foundation


enum Block: Codable, Sendable, Identifiable, Equatable {
    case artifact(Reference)
    case command(Reference)
    case material(Reference)
    case task(UUID, String, Bool)
    case text(UUID, String)

    var id: AnyHashable {
        switch self {
            case .artifact(let ref): return ref
            case .command(let ref): return ref
            case .material(let ref): return ref
            case .task(let id, _, _): return id
            case .text(let id, _): return id
        }
    }
}

enum Entry: Codable, Sendable, Identifiable {
    case event(Signal, Date)
    case record(Chunk, Date)
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
