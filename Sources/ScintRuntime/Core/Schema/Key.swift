import Foundation
import CryptoKit


enum Key: Codable, Sendable, Identifiable, Hashable {
    case context(Reference)
    case descriptor(Reference)
    case mapping(UUID, Reference)

    var id: UUID {
        switch self {
            case .context(let ref): return ref.contextId
            case .descriptor(let ref): return ref.descriptorId
            case .mapping(let id, _): return id
        }
    }

    var ref: Reference {
        switch self {
            case .context(let ref): return ref
            case .descriptor(let ref): return ref
            case .mapping(_, let ref): return ref
        }
    }
}

extension Key {
    private enum CodingKeys: String, CodingKey, CaseIterable { case context, descriptor, mapping }
    private enum Fields: String, CodingKey { case id, ref }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.tag() {
            case .context: self = .context(try c.decode(Reference.self, forKey: .context))
            case .descriptor: self = .descriptor(try c.decode(Reference.self, forKey: .descriptor))
            case .mapping:
                let f = try c.nestedContainer(keyedBy: Fields.self, forKey: .mapping)
                self = .mapping(try f.decode(UUID.self, forKey: .id), try f.decode(Reference.self, forKey: .ref))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .context(let ref): try c.encode(ref, forKey: .context)
            case .descriptor(let ref): try c.encode(ref, forKey: .descriptor)
            case .mapping(let id, let ref):
                var f = c.nestedContainer(keyedBy: Fields.self, forKey: .mapping)
                try f.encode(id, forKey: .id)
                try f.encode(ref, forKey: .ref)
        }
    }
}
