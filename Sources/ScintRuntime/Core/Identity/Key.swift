import Foundation
import CryptoKit


enum Key: Codable, Sendable, Identifiable, Hashable {
    case branch(UUID, Reference)
    case context(Reference)
    case descriptor(Reference)

    var id: UUID {
        switch self {
            case .branch(let id, _): return id
            case .context(let ref): return ref.contextId
            case .descriptor(let ref): return ref.descriptorId
        }
    }

    var ref: Reference {
        switch self {
            case .branch(_, let ref): return ref
            case .context(let ref): return ref
            case .descriptor(let ref): return ref
        }
    }
}
