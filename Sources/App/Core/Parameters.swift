import AgencyRuntime
import SwiftUI


enum TrailingKind: Hashable { case toggle, load, action, value }

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
    let owner: Reference?
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

    init(ref: Reference? = nil, owner: Reference? = nil, origin: Reference? = nil, path: URL? = nil,
         entryId: UUID? = nil, name: String, image: String = "", tint: Color? = nil, trailingImage: String? = nil,
         trailingKind: TrailingKind? = nil, count: Int? = nil, description: String? = nil,
         badges: [BadgeParams] = [], active: Bool = true,  items: [ItemParams] = [], isParent: Bool? = nil) {

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
        self.description = description
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
    let layout: Layout
    let footnote: String?
    let body: String?
    let items: [ItemParams]

    init(id: String? = nil, name: String = "", header: Bool? = nil,
         image: String = "", tint: Color? = nil, layout: Layout = .list,
         footnote: String? = nil, body: String? = nil, items: [ItemParams] = []) {
        self.id = id ?? name.lowercased().replacingOccurrences(of: " ", with: "-")
        self.name = name
        self.header = header ?? true
        self.image = image
        self.tint = tint
        self.layout = layout
        self.footnote = footnote
        self.body = body
        self.items = items
    }
}

struct ColumnParams: Identifiable, Hashable {
    enum CellAlignment: Hashable {
        case leading, center, trailing
        var frameAlignment: Alignment {
            switch self {
            case .leading: .leading
            case .center: .center
            case .trailing: .trailing
            }
        }
        var textAlignment: TextAlignment {
            switch self {
            case .leading: .leading
            case .center: .center
            case .trailing: .trailing
            }
        }
    }

    enum ColumnValue: Hashable {
        case primary
        case name
        case description
        case child(Int)
        case badge
        case badges
        case count
        case text(String)
    }

    let id: AnyHashable
    let title: String
    let width: CGFloat?
    let alignment: CellAlignment
    let value: ColumnValue

    init(id: String? = nil, title: String, width: CGFloat? = nil,
         alignment: CellAlignment = .leading, value: ColumnValue) {
        self.id = id ?? title.lowercased().replacingOccurrences(of: " ", with: "-")
        self.title = title
        self.width = width
        self.alignment = alignment
        self.value = value
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

struct Parameters: Identifiable {
    let id: AnyHashable
    let name: String
    let header: Bool?
    let columns: [ColumnParams]
    let sections: [ListParams]
    let controls: ControlsParams?
    let arrangement: Arrangement
    let nesting: Nesting

    enum Nesting: String, CaseIterable { case recursive, single, flat }
    enum Arrangement { case list, split }

    init(id: String? = nil, name: String = "", nesting: Nesting = .flat, header: Bool? = false,
         arrangement: Arrangement = .list, controls: ControlsParams? = nil,
         sections: [ListParams] = [], columns: [ColumnParams] = []) {

        self.id = id ?? name.lowercased().replacingOccurrences(of: " ", with: "-")
        self.name = name
        self.nesting = nesting
        self.header = header
        self.arrangement = arrangement
        self.controls = controls
        self.sections = sections
        self.columns = columns
    }
}
