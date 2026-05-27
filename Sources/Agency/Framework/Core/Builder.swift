import SwiftUI
import AppKit
import AgencyRuntime
import UniformTypeIdentifiers



@MainActor public enum Builder {
    @ViewBuilder static func build<M: Panel>(_ model: M, _ closures: Closures, _ params: Params) -> some View {
        let view = AnyView(
            ScrollView {
                VStack {
                    if params.header == true {
                        GroupHeader()
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.bottom, 16)
                    }
                    ForEach(params.sections) { section in build(section, model: model, params: params, closures: closures) }
                        .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 8)
        )

        let transferred = surfaceTransfer(view, closures: closures)

        if let actions = closures.surfaceActions?(), !actions.isEmpty {
            transferred.contentShape(Rectangle()).contextMenu { ActionMenu(items: actions) }
        } else { transferred }
    }

    @ViewBuilder static func build<M: Panel>(_ section: ListParams, model: M, params: Params, closures: Closures) -> some View {
        switch section.layout {
        case .group: buildGroup(section, model: model, closures: closures)
        case .grid: buildGrid(section, model: model, params: params, closures: closures)
        case .table: buildTable(section, model: model, params: params, closures: closures)
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

    @ViewBuilder static func buildGrid<M: Panel>(_ section: ListParams, model: M, params: Params, closures: Closures) -> some View {
        VStack(spacing: 0) {
            if section.header { SectionHeader(name: section.name) }
            let gridItem = GridItem(.adaptive(minimum: 128, maximum: 128), spacing: 8, alignment: .topLeading)

            LazyVGrid(columns: [gridItem], alignment: .leading, spacing: 8) {
                ForEach(section.items) { item in
                    let view = AnyView(ItemIcon(item: item, closures: closures))
                    let decorated = transfer(view, item: item, closures: closures)
                    menu(decorated, item: item, closures: closures)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 8)
    }

    @ViewBuilder static func buildGroup<M: Panel>(_ section: ListParams, model: M, closures: Closures) -> some View {
        GroupLayout(title: section.name, footnote: section.footnote ?? "") {
            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { GroupDivider() }
                groupRow(item, closures: closures)
            }
        }
        .padding(.bottom, 8)
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
        case .toggle:
            GroupToggle(isOn: false) { closures.onToggle?(item) }
        case .load:
            LoadAccessory(item: item, closures: closures)
        case .action:
            GroupCountButton(count: item.count) { closures.onSelect?(item) }
        case .value:
            Text(item.description ?? "")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 12)
    }

    @ViewBuilder static func buildTable<M: Panel>(_ section: ListParams, model: M, params: Params, closures: Closures) -> some View {
        TableLayout(section: section, columns: params.columns, closures: closures)
    }

    @ViewBuilder static func menu(_ view: AnyView, item: ItemParams, closures: Closures) -> some View {
        let actions = closures.itemActions?(item) ?? []
        if closures.isEditable && closures.canEdit(item) {
            view.contextMenu {
                ActionMenu(items: actions)
                if !actions.isEmpty && (closures.canRename(item) || closures.canDuplicate(item) || closures.canAddChild(for: item) || closures.canDelete(item)) {
                    Divider()
                }
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
        let canDrag = closures.canDrag?(item) ?? ReferenceTransfer.canDrag(item)
        let withDrag: AnyView

        if canDrag {
            withDrag = AnyView(
                view
                    .contentShape(Rectangle())
                    .onDrag { ReferenceTransfer.provider(for: item) ?? NSItemProvider() }
            )
        }
        else { withDrag = view }

        let types = closures.dropTypes?(item) ?? ReferenceTransfer.dropTypes(for: item)
        guard !types.isEmpty else { return withDrag }

        return AnyView(
            withDrag.onDrop(of: types, isTargeted: nil) { providers in
                closures.onDrop?(providers, item) ?? ReferenceTransfer.handle(providers, target: item)
            }
        )
    }

    static func surfaceTransfer(_ view: AnyView, closures: Closures) -> AnyView {
        guard let target = closures.surfaceDropTarget?() else { return view }
        let types = closures.dropTypes?(target) ?? ReferenceTransfer.dropTypes(for: target)
        guard !types.isEmpty else { return view }

        return AnyView(
            view
                .contentShape(Rectangle())
                .onDrop(of: types, isTargeted: nil) { providers in
                    closures.onDrop?(providers, target) ?? ReferenceTransfer.handle(providers, target: target)
                }
        )
    }
}
