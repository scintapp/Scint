import SwiftUI
import ScintRuntime


struct ItemParams: Hashable, Identifiable {
    let ref: Reference?
    let key: String?
    let origin: Reference?
    let path: URL?
    let entryId: UUID?
    let name: String
    let description: String
    let image: String
    let tint: Color?
    let trailingKind: TrailingKind?
    let count: Int?
    let value: String?
    let active: Bool
    let items: [ItemParams]
    var indent: CGFloat = 0
    private let _isParent: Bool?
    var isParent: Bool { _isParent ?? !items.isEmpty }

    enum TrailingKind: Hashable { case toggle, load, action, picker, range, field, date, time, moment, remove, button }

    init(
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
        self._isParent = isParent
    }

    var id: AnyHashable {
        if let path { return AnyHashable(path) }
        if let entryId { return AnyHashable(entryId) }
        if let ref { return AnyHashable(ref) }
        if let key { return AnyHashable(value.map { "\(key)=\($0)" } ?? key) }
        return AnyHashable(name.lowercased().replacingOccurrences(of: " ", with: "-"))
    }
}
