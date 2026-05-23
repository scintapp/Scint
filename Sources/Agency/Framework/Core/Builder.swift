import SwiftUI
import AppKit
import AgencyRuntime
import UniformTypeIdentifiers


enum TrailingKind: Hashable { case toggle, load, value }
enum ViewLayout: Hashable { case list, grid, column, group, block }

@MainActor public enum Builder {
    @ViewBuilder static func build<M: Panel>(_ model: M, _ closures: Closures, _ params: Params) -> some View {
        VStack {
            ScrollView {
                ForEach(params.sections) { section in
                    build(section, model: model, params: params, closures: closures) }
                        .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 8)
    }

    @ViewBuilder static func build<M: Panel>(_ section: ListParams, model: M, params: Params, closures: Closures) -> some View {
        switch section.layout {
        case .group: buildGroup(section, model: model, closures: closures)
        case .block: buildBlock(section)
        case .grid: buildGrid(section, model: model, params: params, closures: closures)
        case .list, .column: buildList(section, model: model, params: params, closures: closures)
        }
    }

    @ViewBuilder static func build<M: Panel>(_ item: ItemParams, model: M, sectionId: AnyHashable,
                                                 nesting: Params.Nesting, depth: Int, closures: Closures) -> some View {

        let indent = CGFloat(depth) * 16

        let canExpand: Bool = {
            switch nesting {
            case .recursive: return true
            case .single: return depth == 0
            case .flat: return false
            }
        }()

        if item.isParent && canExpand {
            let sectionView = AnyView(
                SectionLayout(
                    name: item.name,
                    image: item.image,
                    trailingImage: item.trailingImage,
                    count: item.count,
                    indent: indent,
                    isExpanded: model.isExpanded(item.id),
                    selected: closures.selected?(item) ?? false,
                    onSelect: { closures.onSelect?(item) },
                    onToggleExpanded: { model.setExpanded(item.id) }
                ) {
                    ForEach(item.items) { child in
                        build(child, model: model, sectionId: sectionId, nesting: nesting, depth: depth + 1, closures: closures)
                    }
                }
            )

            let wrapped = closures.wrapSection?(sectionView, item, depth) ?? sectionView
            let decorated = transfer(wrapped, item: item, closures: closures)

            menu(decorated, item: item, closures: closures)
        } else {
            let linkView = AnyView(
                SectionLink(
                    name: item.name,
                    image: item.image,
                    trailingImage: item.trailingImage,
                    count: item.count,
                    indent: indent,
                    selected: closures.selected?(item) ?? false,
                    onSelect: { closures.onSelect?(item) }
                )
            )

            let wrapped = closures.wrapLink?(linkView, item, depth) ?? linkView
            let decorated = transfer(wrapped, item: item, closures: closures)
            menu(decorated, item: item, closures: closures)
        }
    }

    @ViewBuilder static func build<M: Panel>(_ section: ListParams, model: M, closures: Closures) -> some View {
        GroupLayout(title: section.name, footnote: section.footnote ?? "") {
            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { GroupDivider() }
                groupRow(item, closures: closures)
            }
        }
    }

    @ViewBuilder static func buildGrid<M: Panel>(_ section: ListParams, model: M, params: Params, closures: Closures) -> some View {
        VStack(spacing: 0) {
            if section.header { SectionHeader(name: section.name) }
            let item = GridItem(.adaptive(minimum: 160, maximum: 160), spacing: 16, alignment: .topLeading)

            LazyVGrid(columns: [item], alignment: .leading, spacing: 16) {
                ForEach(section.items) { item in
                    let view = AnyView(ItemCard(item: item, closures: closures))
                    let decorated = transfer(view, item: item, closures: closures)
                    menu(decorated, item: item, closures: closures)
                }
            }
        }
    }

    @ViewBuilder static func buildGroup<M: Panel>(_ section: ListParams, model: M, closures: Closures) -> some View {
        GroupLayout(title: section.name, footnote: section.footnote ?? "") {
            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { GroupDivider() }
                groupRow(item, closures: closures)
            }
        }
    }

    @ViewBuilder static func groupRow(_ item: ItemParams, closures: Closures) -> some View {
        if item.ref != nil || item.entryId != nil {
            Button { closures.onSelect?(item) } label: {
                GroupRow(label: item.name) {
                    Image(systemName: item.image)
                } trailing: {
                    groupRowAccessory(item, closures: closures)
                }
            }
            .buttonStyle(.plain)
        } else {
            GroupRow(label: item.name) {
                Image(systemName: item.image)
            } trailing: {
                groupRowAccessory(item, closures: closures)
            }
        }
    }

    @ViewBuilder static func groupRowAccessory(_ item: ItemParams, closures: Closures) -> some View {
        switch item.trailingKind {
        case .toggle: GroupToggle(isOn: false) { }
        case .load: GroupCountButton(count: item.count) { }
        case .value:
            Text(item.description ?? "")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        default: EmptyView()
        }
    }

    @ViewBuilder static func buildList<M: Panel>(_ section: ListParams, model: M, params: Params, closures: Closures) -> some View {
        VStack(spacing: 0) {
            if section.header {
                let header = AnyView(SectionHeader(
                    name: section.name,
                    onAdd: closures.canAddInline(sectionId: String(describing: section.id)) ? {
                        closures.onAddItem?(AnyHashable(section.id), "")
                    } : nil
                ))

                if let wrapHeader = closures.wrapHeader { wrapHeader(header, section) }
                else { header }
            }

            ForEach(section.items) { item in
                build(item, model: model, sectionId: section.id, nesting: params.nesting, depth: 0, closures: closures)
            }

            if closures.canAddInline(sectionId: section.id) {
                SectionAddItemRow(placeholder: "New Item") { name in
                    closures.onAddItem?(AnyHashable(section.id), name)
                }
            }
        }
    }

    @ViewBuilder static func buildBlock(_ section: ListParams) -> some View {
        Block(
            title: section.name,
            text: section.body ?? "",
            footnote: section.footnote ?? "",
        )
    }

    @ViewBuilder static func menu(_ view: AnyView, item: ItemParams, closures: Closures) -> some View {
        if closures.isEditable && closures.canEdit(item) {
            view.contextMenu {
                ItemContextMenu(
                    item: item,
                    onRename: closures.canRename(item) ? { closures.onRename?(item.id, item.name) } : nil,
                    onDuplicate: closures.canDuplicate(item) ? { closures.onDuplicate?(item.id) } : nil,
                    onDelete: closures.canDelete(item) ? { closures.onDelete?(item.id) } : nil,
                    onAddChild: closures.canAddChild(for: item) ? { closures.onAddItem?(item.id, "") } : nil
                )
            }
        }
        else { view }
    }

    @ViewBuilder static func build(_ params: ControlsParams, _ closures: Closures) -> some View {
        ZStack(alignment: .bottom) { }
    }

    static func transfer(_ view: AnyView, item: ItemParams, closures: Closures) -> AnyView {
        let canDrag = closures.canDrag?(item) ?? (item.ref != nil)
        let withDrag: AnyView

        if false, canDrag, let _ = item.ref { withDrag = view }
        else { withDrag = view }

        let types = closures.dropTypes?(item) ?? []
        guard !types.isEmpty, closures.onDrop != nil else { return withDrag }

        return AnyView(
            withDrag.onDrop(of: types, isTargeted: nil) { providers in
                closures.onDrop?(providers, item) ?? false
            }
        )
    }
}

struct Closures {
    var onToggle: ((ItemParams) -> Void)?
    var setControls: ((_ controls: ControlsParams) -> AnyView)?
    var selected: ((_ item: ItemParams) -> Bool)?
    var onSelect: ((_ item: ItemParams) -> Void)?
    var onOpen: ((_ item: ItemParams) -> Void)?
    var onAddItem: ((_ parentId: AnyHashable, _ name: String) -> Void)?
    var onAddSection: ((_ name: String) -> Void)?
    var onRename: ((_ id: AnyHashable, _ newName: String) -> Void)?
    var onDelete: ((_ id: AnyHashable) -> Void)?
    var onDuplicate: ((_ id: AnyHashable) -> Void)?
    var onMove: ((_ id: AnyHashable, _ newParentId: AnyHashable, _ index: Int) -> Void)?
    var wrapLink: ((_ view: AnyView, _ item: ItemParams, _ depth: Int) -> AnyView)?
    var wrapSection: ((_ view: AnyView, _ item: ItemParams, _ depth: Int) -> AnyView)?
    var wrapHeader: ((_ view: AnyView, _ section: ListParams) -> AnyView)?
    var itemAccessory: ((_ item: ItemParams, _ depth: Int) -> AnyView?)?
    var sectionAccessory: ((_ item: ItemParams, _ depth: Int) -> AnyView?)?
    var addableSections: Set<AnyHashable>?
    var isItemEditable: ((_ item: ItemParams) -> Bool)?
    var canAddChild: ((_ item: ItemParams) -> Bool)?
    var isItemRenameable: ((_ item: ItemParams) -> Bool)?
    var isItemDeleteable: ((_ item: ItemParams) -> Bool)?
    var isItemDuplicateable: ((_ item: ItemParams) -> Bool)?
    var canDrag: ((_ item: ItemParams) -> Bool)?
    var dropTypes: ((_ item: ItemParams) -> [UTType])?
    var onDrop: ((_ providers: [NSItemProvider], _ target: ItemParams) -> Bool)?

    init(
        onToggle: ((ItemParams) -> Void)? = nil,
        setControls: ((_ controls: ControlsParams) -> AnyView)? = nil,
        selected: ((_ item: ItemParams) -> Bool)? = nil,
        onSelect: ((_ item: ItemParams) -> Void)? = nil,
        onOpen: ((_ item: ItemParams) -> Void)? = nil,
        onAddItem: ((_ parentId: AnyHashable, _ name: String) -> Void)? = nil,
        onAddSection: ((_ name: String) -> Void)? = nil,
        onRename: ((_ id: AnyHashable, _ newName: String) -> Void)? = nil,
        onDelete: ((_ id: AnyHashable) -> Void)? = nil,
        onDuplicate: ((_ id: AnyHashable) -> Void)? = nil,
        onMove: ((_ id: AnyHashable, _ newParentId: AnyHashable, _ index: Int) -> Void)? = nil,
        wrapLink: ((_ view: AnyView, _ item: ItemParams, _ depth: Int) -> AnyView)? = nil,
        wrapSection: ((_ view: AnyView, _ item: ItemParams, _ depth: Int) -> AnyView)? = nil,
        wrapHeader: ((_ view: AnyView, _ section: ListParams) -> AnyView)? = nil,
        itemAccessory: ((_ item: ItemParams, _ depth: Int) -> AnyView?)? = nil,
        sectionAccessory: ((_ item: ItemParams, _ depth: Int) -> AnyView?)? = nil,
        addableSections: Set<AnyHashable>? = nil,
        isItemEditable: ((_ item: ItemParams) -> Bool)? = nil,
        canAddChild: ((_ item: ItemParams) -> Bool)? = nil,
        isItemRenameable: ((_ item: ItemParams) -> Bool)? = nil,
        isItemDeleteable: ((_ item: ItemParams) -> Bool)? = nil,
        isItemDuplicateable: ((_ item: ItemParams) -> Bool)? = nil,
        canDrag: ((_ item: ItemParams) -> Bool)? = nil,
        dropTypes: ((_ item: ItemParams) -> [UTType])? = nil,
        onDrop: ((_ providers: [NSItemProvider], _ target: ItemParams) -> Bool)? = nil
    ) {
        self.onToggle = onToggle
        self.setControls = setControls
        self.selected = selected
        self.onSelect = onSelect
        self.onOpen = onOpen
        self.onAddItem = onAddItem
        self.onAddSection = onAddSection
        self.onRename = onRename
        self.onDelete = onDelete
        self.onDuplicate = onDuplicate
        self.onMove = onMove
        self.wrapLink = wrapLink
        self.wrapSection = wrapSection
        self.wrapHeader = wrapHeader
        self.itemAccessory = itemAccessory
        self.sectionAccessory = sectionAccessory
        self.addableSections = addableSections
        self.isItemEditable = isItemEditable
        self.canAddChild = canAddChild
        self.isItemRenameable = isItemRenameable
        self.isItemDeleteable = isItemDeleteable
        self.isItemDuplicateable = isItemDuplicateable
        self.canDrag = canDrag
        self.dropTypes = dropTypes
        self.onDrop = onDrop
    }

    var isEditable: Bool {
        onAddItem != nil || onAddSection != nil || onRename != nil ||
        onDelete != nil || onDuplicate != nil || onMove != nil
    }

    func canEdit(_ item: ItemParams) -> Bool {
        isItemEditable?(item) ?? true
    }

    func canAddChild(for item: ItemParams) -> Bool {
        guard onAddItem != nil else { return false }
        return canAddChild?(item) ?? item.isParent
    }

    func canRename(_ item: ItemParams) -> Bool {
        guard onRename != nil else { return false }
        return isItemRenameable?(item) ?? true
    }

    func canDelete(_ item: ItemParams) -> Bool {
        guard onDelete != nil else { return false }
        return isItemDeleteable?(item) ?? true
    }

    func canDuplicate(_ item: ItemParams) -> Bool {
        guard onDuplicate != nil else { return false }
        return isItemDuplicateable?(item) ?? true
    }

    func canAddInline(sectionId: AnyHashable) -> Bool {
        guard onAddItem != nil else { return false }
        guard let allowed = addableSections else { return true }
        return allowed.contains(sectionId)
    }
}

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
