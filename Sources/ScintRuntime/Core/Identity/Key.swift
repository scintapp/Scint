import Foundation
import CryptoKit


enum Key: Codable, Sendable, Identifiable, Hashable {
    case context(Reference)
    case descriptor(Reference)
    case map(UUID, Reference)

    var id: UUID {
        switch self {
            case .map(let id, _): return id
            case .context(let ref): return ref.contextId
            case .descriptor(let ref): return ref.descriptorId
        }
    }

    var ref: Reference {
        switch self {
            case .map(_, let ref): return ref
            case .context(let ref): return ref
            case .descriptor(let ref): return ref
        }
    }
}
