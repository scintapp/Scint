import AgencyRuntime
import SwiftUI


struct ItemParams: Identifiable, Hashable {
    let ref: Reference?
    let owner: Reference?
    let origin: Reference?
    let path: URL?
    let entryId: UUID?
    let name: String
    let description: String
    let image: String
    let tint: Color?
    let trailingImage: String?
    let trailingKind: TrailingKind?
    let count: Int?
    let value: String?
    let active: Bool
    let items: [ItemParams]
    private let _isParent: Bool?
    var isParent: Bool { _isParent ?? !items.isEmpty }

    enum TrailingKind: Hashable { case toggle, load, action, value }

    init(
        ref: Reference? = nil,
        owner: Reference? = nil,
        origin: Reference? = nil,
        path: URL? = nil,
        entryId: UUID? = nil,
        name: String,
        image: String = "",
        icon: Iconography.Icon? = nil,
        tint: Color? = nil,
        trailingImage: String? = nil,
        trailingKind: TrailingKind? = nil,
        count: Int? = nil,
        value: String? = nil,
        description: String = "",
        active: Bool = true,
        items: [ItemParams] = [],
        isParent: Bool? = nil
    ) {
        self.ref = ref
        self.owner = owner
        self.origin = origin
        self.path = path
        self.entryId = entryId
        self.name = name
        self.image = image
        self.tint = tint
        self.trailingImage = trailingImage
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
        return AnyHashable(name.lowercased().replacingOccurrences(of: " ", with: "-"))
    }
}

struct ComponentParams: Identifiable, Hashable {
    let id: AnyHashable
    let name: String
    let header: Bool
    let footer: String?
    let tint: Color?
    let image: String
    let items: [ItemParams]

    init(id: String? = nil,
         name: String? = nil,
         header: Bool? = nil,
         footer: String? = nil,
         image: String? = nil,
         tint: Color? = nil,
         items: [ItemParams] = []
    ) {
        self.id = id ?? (name ?? "").lowercased().replacingOccurrences(of: " ", with: "-")
        self.name = name ?? ""
        self.header = header ?? true
        self.image = image ?? ""
        self.tint = tint ?? nil
        self.footer = footer
        self.items = items
    }
}

struct Params: Identifiable {
    let id: AnyHashable
    let ref: Reference?
    let name: String
    let description: String
    let header: Bool?
    let components: [ComponentParams]
    let layout: Layout?
    let nesting: Nesting?

    init(
        id: AnyHashable? = nil,
        ref: Reference? = nil,
        name: String = "",
        description: String = "",
        layout: Layout? = nil,
        nesting: Nesting? = .flat,
        header: Bool? = false,
        components: [ComponentParams] = []
    ) {
        self.id = id ?? AnyHashable("panel")
        self.ref = ref
        self.name = name
        self.description = description
        self.layout = layout
        self.nesting = nesting
        self.header = header
        self.components = components

    }
}
