import Foundation


public struct Descriptor: Keyable {
    public let key: Key
    public var origin: Reference
    public var framing: Framing
    public var name: String
    public var description: String
    public var tags: Set<String>
    public var created: Date
    public var updated: Date
    public var accessed: Date
    public var published: Bool

    public enum Framing: String, Codable, Sendable, CaseIterable {
        case scint = "scint"
        case palette = "palette"
        case server = "server"
        case studio = "studio"
    }

    public init(_ ref: Reference, _ name: String, _ framing: Framing = .scint) {
        self.key = .descriptor(ref)
        self.origin = ref
        self.framing = framing
        self.name = name
        self.description = ""
        self.tags = []
        self.published = true
        self.created = .now
        self.updated = .now
        self.accessed = .now
    }

    public static func new(_ ref: Reference, framing: Framing? = .scint, name: String, description: String? = "", tags: Set<String> = [], published: Bool = true) {
        var instance = Self(ref, name, framing ?? .scint)
        instance.name = name
        instance.description = description ?? ""
        instance.tags = tags
        instance.published = published
        Catalog.shared.set(ref, instance)
    }
}
