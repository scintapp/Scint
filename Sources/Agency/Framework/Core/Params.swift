import SwiftUI
import AgencyRuntime
import UniformTypeIdentifiers


enum TrailingKind: Hashable { case toggle, load, value }
enum ViewLayout: Hashable { case list, grid, column, group, block }

struct HeaderParams {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
}

struct BadgeParams: Identifiable, Hashable {
    let id: AnyHashable
    let icon: String
    let label: String
    let count: Int
    let tint: Color

    init(id: String? = nil, icon: String, label: String, count: Int, tint: Color) {
        self.id = id ?? icon
        self.icon = icon
        self.label = label
        self.count = count
        self.tint = tint
    }
}

struct ItemParams: Identifiable, Hashable {
    let ref: Reference?
    let origin: Reference?
    let path: URL?
    let entryId: UUID?
    let name: String
    let description: String?
    let image: String
    let tint: Color?
    let trailingImage: String?
    let trailingKind: TrailingKind?
    let count: Int?
    let tags: [String]
    let badges: [BadgeParams]
    let active: Bool
    let items: [ItemParams]
    private let _isParent: Bool?

    var isParent: Bool { _isParent ?? !items.isEmpty }

    var id: AnyHashable {
        if let path { return AnyHashable(path) }
        if let entryId { return AnyHashable(entryId) }
        if let ref { return AnyHashable(ref) }
        return AnyHashable(name.lowercased().replacingOccurrences(of: " ", with: "-"))
    }

    init(ref: Reference? = nil, origin: Reference? = nil, path: URL? = nil, entryId: UUID? = nil,
         name: String, image: String = "", tint: Color? = nil,
         trailingImage: String? = nil, trailingKind: TrailingKind? = nil, count: Int? = nil, description: String? = nil,
         tags: [String] = [], badges: [BadgeParams] = [], active: Bool = true,
         items: [ItemParams] = [], isParent: Bool? = nil) {

        self.ref = ref
        self.origin = origin
        self.path = path
        self.entryId = entryId
        self.name = name
        self.image = image
        self.tint = tint
        self.trailingImage = trailingImage
        self.trailingKind = trailingKind
        self.count = count
        self.description = description
        self.tags = tags
        self.badges = badges
        self.active = active
        self.items = items
        self._isParent = isParent
    }
}

struct ListParams: Identifiable, Hashable {
    let id: AnyHashable
    let name: String
    let header: Bool
    let image: String
    let tint: Color?
    let layout: ViewLayout
    let footnote: String?
    let body: String?
    let items: [ItemParams]

    init(id: String? = nil, name: String = "", showsHeader: Bool? = nil,
         image: String = "", tint: Color? = nil, layout: ViewLayout = .list,
         footnote: String? = nil, body: String? = nil, items: [ItemParams] = []) {
        self.id = id ?? name.lowercased().replacingOccurrences(of: " ", with: "-")
        self.name = name
        self.header = showsHeader ?? true
        self.image = image
        self.tint = tint
        self.layout = layout
        self.footnote = footnote
        self.body = body
        self.items = items
    }
}

struct ControlsParams: Identifiable, Hashable {
    let id: AnyHashable
    let name: String
    let filter: Bool

    init(id: String? = nil, name: String, filter: Bool = false) {
        self.id = id ?? name.lowercased().replacingOccurrences(of: " ", with: "-")
        self.name = name
        self.filter = filter
    }
}

struct Params: Identifiable {
    let id: AnyHashable
    let name: String
    let nesting: Nesting
    let header: HeaderParams?
    let arrangement: Arrangement
    let sections: [ListParams]
    let controls: ControlsParams?

    enum Nesting: String, CaseIterable { case recursive, single, flat }
    enum Arrangement { case list, split }

    init(id: String? = nil, name: String = "", nesting: Nesting = .flat,
         header: HeaderParams? = nil, arrangement: Arrangement = .list,
         controls: ControlsParams? = nil, sections: [ListParams] = []) {
        self.id = id ?? name.lowercased().replacingOccurrences(of: " ", with: "-")
        self.name = name
        self.nesting = nesting
        self.header = header
        self.arrangement = arrangement
        self.controls = controls
        self.sections = sections
    }
}
