import SwiftUI
import ScintRuntime


public struct ItemParams: Hashable, Identifiable {
    public let ref: Reference?
    public let key: String?
    public let origin: Reference?
    public let path: URL?
    public let entryId: UUID?
    public let name: String
    public let description: String
    public let image: String
    public let tint: Color?
    public let trailingKind: TrailingKind?
    public let count: Int?
    public let value: String?
    public var active: Bool
    public let items: [ItemParams]
    public let keywords: [String]
    public var indent: CGFloat = 0
    public let _isParent: Bool?
    public var isParent: Bool { _isParent ?? !items.isEmpty }

    public enum TrailingKind: Hashable { case toggle, load, action, picker, range, field, date, time, moment, remove, button }

    public init(
        ref: Reference? = nil,
        key: String? = nil,
        origin: Reference? = nil,
        path: URL? = nil,
        entryId: UUID? = nil,
        name: String,
        image: String = "",
        tint: Color? = nil,
        trailingKind: TrailingKind? = nil,
        count: Int? = nil,
        value: String? = nil,
        description: String = "",
        active: Bool = true,
        items: [ItemParams] = [],
        keywords: [String] = [],
        isParent: Bool? = nil
    ) {
        self.ref = ref
        self.key = key
        self.origin = origin
        self.path = path
        self.entryId = entryId
        self.name = name
        self.image = image
        self.tint = tint
        self.trailingKind = trailingKind
        self.count = count
        self.value = value
        self.description = description
        self.active = active
        self.items = items
        self.keywords = keywords
        self._isParent = isParent
    }

    public var id: AnyHashable {
        if let path { return AnyHashable(path) }
        if let entryId { return AnyHashable(entryId) }
        if let ref { return AnyHashable(ref) }
        if let key { return AnyHashable(value.map { "\(key)=\($0)" } ?? key) }
        return AnyHashable(name.lowercased().replacingOccurrences(of: " ", with: "-"))
    }
}
