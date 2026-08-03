import Foundation


public enum Key: Codable, Sendable, Identifiable, Hashable {
    case context(ContextId)
    case descriptor(DescriptorId)

    public var id: UUID {
        switch self {
        case .context(let id): return id
        case .descriptor(let id): return id
        }
    }
}

