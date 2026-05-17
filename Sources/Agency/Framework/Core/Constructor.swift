import SwiftUI
import AppKit
import AgencyRuntime


@MainActor public enum Constructor {
    @ViewBuilder static func build<M: Frame>(_ model: M, _ params: Params, _ controls: Controls) -> some View {
        VStack {
            ScrollView {
                ForEach(params.sections) { section in
                    build(section, model: model, params: params, controls: controls) }
                        .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 8)
    }

    @ViewBuilder static func build<M: Frame>(_ section: ListParams, model: M, params: Params, controls: Controls) -> some View {
        switch section.layout {
        case .group: buildGroup(section, model: model, controls: controls)
        case .block: buildBlock(section)
        case .grid: buildGrid(section, model: model, params: params, controls: controls)
        case .list, .column: buildList(section, model: model, params: params, controls: controls)
        }
    }

    @ViewBuilder static func build<M: Frame>(_ item: ItemParams, model: M, sectionId: AnyHashable,
                                                 nesting: Params.Nesting, depth: Int, controls: Controls) -> some View {

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
                    selected: controls.selected?(item) ?? false,
                    onSelect: { controls.onSelect?(item) },
                    onToggleExpanded: { model.setExpanded(item.id) }
                ) {
                    ForEach(item.items) { child in
                        build(child, model: model, sectionId: sectionId, nesting: nesting, depth: depth + 1, controls: controls)
                    }
                }
            )

            let wrapped = controls.wrapSection?(sectionView, item, depth) ?? sectionView
            let decorated = transfer(wrapped, item: item, controls: controls)

            menu(decorated, item: item, controls: controls)
        } else {
            let linkView = AnyView(
                SectionLink(
                    name: item.name,
                    image: item.image,
                    trailingImage: item.trailingImage,
                    count: item.count,
                    indent: indent,
                    selected: controls.selected?(item) ?? false,
                    onSelect: { controls.onSelect?(item) }
                )
            )

            let wrapped = controls.wrapLink?(linkView, item, depth) ?? linkView
            let decorated = transfer(wrapped, item: item, controls: controls)
            menu(decorated, item: item, controls: controls)
        }
    }

    @ViewBuilder static func build<M: Frame>(_ section: ListParams, model: M, controls: Controls) -> some View {
        GroupLayout(title: section.name, footnote: section.footnote ?? "") {
            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { GroupDivider() }
                groupRow(item, controls: controls)
            }
        }
    }

    @ViewBuilder static func buildGrid<M: Frame>(_ section: ListParams, model: M, params: Params, controls: Controls) -> some View {
        VStack(spacing: 0) {
            if section.header { SectionHeader(name: section.name) }
            let item = GridItem(.adaptive(minimum: 160, maximum: 160), spacing: 16, alignment: .topLeading)

            LazyVGrid(columns: [item], alignment: .leading, spacing: 16) {
                ForEach(section.items) { item in
                    let view = AnyView(ItemCard(item: item, settings: controls))
                    let decorated = transfer(view, item: item, controls: controls)
                    menu(decorated, item: item, controls: controls)
                }
            }
        }
    }

    @ViewBuilder static func buildGroup<M: Frame>(_ section: ListParams, model: M, controls: Controls) -> some View {
        GroupLayout(title: section.name, footnote: section.footnote ?? "") {
            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { GroupDivider() }
                groupRow(item, controls: controls)
            }
        }
    }

    @ViewBuilder static func groupRow(_ item: ItemParams, controls: Controls) -> some View {
        if item.ref != nil || item.entryId != nil {
            Button { controls.onSelect?(item) } label: {
                GroupRow(label: item.name) {
                    Image(systemName: item.image)
                } trailing: {
                    groupRowAccessory(item, controls: controls)
                }
            }
            .buttonStyle(.plain)
        } else {
            GroupRow(label: item.name) {
                Image(systemName: item.image)
            } trailing: {
                groupRowAccessory(item, controls: controls)
            }
        }
    }

    @ViewBuilder static func groupRowAccessory(_ item: ItemParams, controls: Controls) -> some View {
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

    @ViewBuilder static func buildList<M: Frame>(_ section: ListParams, model: M, params: Params, controls: Controls) -> some View {
        VStack(spacing: 0) {
            if section.header {
                let header = AnyView(SectionHeader(
                    name: section.name,
                    onAdd: controls.canAddInline(sectionId: String(describing: section.id)) ? {
                        controls.onAddItem?(AnyHashable(section.id), "")
                    } : nil
                ))

                if let wrapHeader = controls.wrapHeader { wrapHeader(header, section) }
                else { header }
            }

            ForEach(section.items) { item in
                build(item, model: model, sectionId: section.id, nesting: params.nesting, depth: 0, controls: controls)
            }

            if controls.canAddInline(sectionId: section.id) {
                SectionAddItemRow(placeholder: "New Item") { name in
                    controls.onAddItem?(AnyHashable(section.id), name)
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

    @ViewBuilder static func menu(_ view: AnyView, item: ItemParams, controls: Controls) -> some View {
        if controls.isEditable && controls.canEdit(item) {
            view.contextMenu {
                ItemContextMenu(
                    item: item,
                    onRename: controls.canRename(item) ? { controls.onRename?(item.id, item.name) } : nil,
                    onDuplicate: controls.canDuplicate(item) ? { controls.onDuplicate?(item.id) } : nil,
                    onDelete: controls.canDelete(item) ? { controls.onDelete?(item.id) } : nil,
                    onAddChild: controls.canAddChild(for: item) ? { controls.onAddItem?(item.id, "") } : nil
                )
            }
        }
        else { view }
    }

    @ViewBuilder static func build(_ params: ControlsParams, _ controls: Controls) -> some View {
        ZStack(alignment: .bottom) { }
    }

    static func transfer(_ view: AnyView, item: ItemParams, controls: Controls) -> AnyView {
        let canDrag = controls.canDrag?(item) ?? (item.ref != nil)
        let withDrag: AnyView

        if false, canDrag, let _ = item.ref { withDrag = view }
        else { withDrag = view }

        let types = controls.dropTypes?(item) ?? []
        guard !types.isEmpty, controls.onDrop != nil else { return withDrag }

        return AnyView(
            withDrag.onDrop(of: types, isTargeted: nil) { providers in
                controls.onDrop?(providers, item) ?? false
            }
        )
    }
}
