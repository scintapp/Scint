import SwiftUI


enum Modality: CaseIterable { case fixed, floating }
enum Layout: CaseIterable { case grid, group, list, table }
enum Nesting: String, CaseIterable { case recursive, single, flat }

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
    let trailingImage: String?
    let trailingKind: TrailingKind?
    let count: Int?
    let value: String?
    let active: Bool
    var layout: Layout?
    let items: [ItemParams]
    private let _isParent: Bool?
    var isParent: Bool { _isParent ?? !items.isEmpty }

    enum TrailingKind: Hashable { case toggle, load, action, value, picker, range, field, date, time, remove, button }

    init(
        ref: Reference? = nil,
        key: String? = nil,
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
        layout: Layout? = nil,
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
        self.trailingImage = trailingImage
        self.trailingKind = trailingKind
        self.count = count
        self.value = value
        self.description = description
        self.active = active
        self.layout = layout
        self.items = items
        self._isParent = isParent
    }

    /// Temporary: until call sites declare an item's layout, the section it is built in lends its own.
    init(_ params: ItemParams, layout: Layout?) {
        self = params
        self.layout = layout
    }

    var id: AnyHashable {
        if let path { return AnyHashable(path) }
        if let entryId { return AnyHashable(entryId) }
        if let ref { return AnyHashable(ref) }
        if let key { return AnyHashable(value.map { "\(key)=\($0)" } ?? key) }
        return AnyHashable(name.lowercased().replacingOccurrences(of: " ", with: "-"))
    }
}

struct SectionParams: Hashable, Identifiable {
    let id: AnyHashable
    let name: String
    let header: Bool
    let footer: String?
    let tint: Color?
    let image: String
    var layout: Layout?
    let nesting: Nesting?
    let items: [ItemParams]
    private let _isParent: Bool?
    var isParent: Bool { _isParent ?? !items.isEmpty }

    init(id: String? = nil,
         name: String? = nil,
         header: Bool? = nil,
         footer: String? = nil,
         image: String? = nil,
         tint: Color? = nil,
         layout: Layout? = nil,
         nesting: Nesting? = nil,
         items: [ItemParams] = [],
         isParent: Bool? = nil
    ) {
        self.id = id ?? (name ?? "").lowercased().replacingOccurrences(of: " ", with: "-")
        self.name = name ?? ""
        self.header = header ?? true
        self.image = image ?? ""
        self.tint = tint ?? nil
        self.footer = footer
        self.layout = layout
        self.nesting = nesting
        self.items = items
        self._isParent = isParent
    }

    /// Temporary: until call sites declare a section's layout, the base lends it the one it resolved.
    init(_ params: SectionParams, layout: Layout?) {
        self = params
        self.layout = layout
    }
}

struct PanelParams: Hashable, Identifiable {
    let key: PanelKey
    let sizing: Sizing
    let input: ItemParams?
    let items: [ItemParams]
    let selection: ItemParams?
    let dismissal: PanelDismissal
    let movable: Bool
    let resizable: Bool
    let pinnable: Bool

    var id: PanelKey { key }

    enum Kind { case floating, fixed }

    struct Sizing: Hashable {
        let size: CGSize
        let min: CGSize?
        let max: CGSize?

        init(size: CGSize, min: CGSize? = nil, max: CGSize? = nil) {
            self.size = size
            self.min = min
            self.max = max
        }
    }

    init(
        key: PanelKey,
        sizing: Sizing,
        input: ItemParams? = nil,
        items: [ItemParams] = [],
        selection: ItemParams? = nil,
        dismissal: PanelDismissal = [.escape, .outsideClick],
        movable: Bool = true,
        resizable: Bool = false,
        pinnable: Bool = false,
    ) {
        self.key = key
        self.sizing = sizing
        self.input = input
        self.items = items
        self.selection = selection
        self.dismissal = dismissal
        self.movable = movable
        self.resizable = resizable
        self.pinnable = pinnable
    }
}

struct Params: Hashable, Identifiable {
    let id: AnyHashable
    let ref: Reference?
    let name: String
    let description: String
    let header: Bool
    let panel: PanelParams?
    let sections: [SectionParams]
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
        panel: PanelParams? = nil,
        sections: [SectionParams] = []
    ) {
        self.id = id ?? AnyHashable("host")
        self.ref = ref
        self.name = name
        self.description = description
        self.layout = layout
        self.nesting = nesting
        self.header = header ?? false
        self.panel = panel
        self.sections = sections

    }
}
