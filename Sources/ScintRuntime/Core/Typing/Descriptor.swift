import Foundation


struct Descriptor: Keyable {
    var key: Key { .descriptor(origin) }
    var origin: Reference
    var name: String
    var description: String
    var tags: Set<String>
    var created: Date
    var updated: Date
    var accessed: Date
    var published: Bool

    init(_ ref: Reference, _ name: String) {
        self.origin = ref
        self.name = name
        self.description = ""
        self.tags = []
        self.published = true
        self.created = .now
        self.updated = .now
        self.accessed = .now
    }

    static func new(_ ref: Reference, name: String, description: String? = "", tags: Set<String> = [], published: Bool = true) {
        var instance = Self(ref, name)
        instance.name = name
        instance.description = description ?? ""
        instance.tags = tags
        instance.published = published
        Catalog.shared.set(ref, instance)
    }
}
