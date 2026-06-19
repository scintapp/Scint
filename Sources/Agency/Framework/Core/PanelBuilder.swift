import SwiftUI


@MainActor public enum Builder {
    static func build<P: Panel>(_ model: AgencyModel, _ panel: P) -> some View {
        let params = panel.parameters(model)
        let controls = panel.controls(model)
        
        let view = AnyView(
            ScrollView {
                VStack {
                    if params.header == true {
                        GroupHeader()
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.bottom, 12)
                    }
                    ForEach(params.sections) { section in
                        build(section, model: panel, params: params, controls: controls)
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )

        let transfer = surfaceTransfer(view, controls: controls)
        if let actions = controls.surfaceActions?(), !actions.isEmpty {
            return AnyView(transfer.contentShape(Rectangle()).contextMenu { ActionMenu(items: actions) })
        } else { return transfer }
    }

    @ViewBuilder static func build<M: Panel>(_ section: ListParams, model: M, params: Parameters, controls: Controls) -> some View {
        switch section.layout {
        case .group: buildGroup(section, model: model, controls: controls)
        case .grid: buildGrid(section, model: model, params: params, controls: controls)
        case .table: buildTable(section, model: model, params: params, controls: controls)
        case .content, .list, .column: buildList(section, model: model, params: params, controls: controls)
        }
    }

    @ViewBuilder static func build<M: Panel>(_ item: ItemParams, model: M, sectionId: AnyHashable,
                                             nesting: Parameters.Nesting, depth: Int, controls: Controls) -> some View {
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
                    ref: item.path == nil && item.entryId == nil ? item.ref : nil,
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
                    ref: item.path == nil && item.entryId == nil ? item.ref : nil,
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

    @ViewBuilder static func buildGrid<M: Panel>(_ section: ListParams, model: M, params: Parameters, controls: Controls) -> some View {
        VStack(spacing: 0) {
            if section.header { SectionHeader(name: section.name) }
            let gridItem = GridItem(.adaptive(minimum: 128, maximum: 128), spacing: 8, alignment: .topLeading)

            LazyVGrid(columns: [gridItem], alignment: .leading, spacing: 8) {
                ForEach(section.items) { item in
                    let view = AnyView(ItemIcon(item: item, controls: controls))
                    let decorated = transfer(view, item: item, controls: controls)
                    menu(decorated, item: item, controls: controls)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder static func buildGroup<M: Panel>(_ section: ListParams, model: M, controls: Controls) -> some View {
        GroupLayout(title: section.name, footnote: section.footnote ?? "") {
            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { GroupDivider() }
                groupRow(item, controls: controls)
            }
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder static func groupRow(_ item: ItemParams, controls: Controls) -> some View {
        if item.ref != nil || item.entryId != nil {
            Button { controls.onSelect?(item) } label: {
                GroupRow(label: item.name) {
                    if let ref = item.ref, item.path == nil && item.entryId == nil {
                        Iconography.icon(for: ref)
                    } else {
                        Image(systemName: item.image)
                    }
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
        case .toggle:
            GroupToggle(isOn: false) { controls.onToggle?(item) }
        case .load:
            LoadAccessory(item: item, controls: controls)
        case .action:
            GroupCountButton(count: item.count) { controls.onSelect?(item) }
        case .value:
            Text(item.description ?? "")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        default: EmptyView()
        }
    }

    @ViewBuilder static func buildList<M: Panel>(_ section: ListParams, model: M, params: Parameters, controls: Controls) -> some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder static func buildTable<M: Panel>(_ section: ListParams, model: M, params: Parameters, controls: Controls) -> some View {
        TableLayout(section: section, columns: params.columns, controls: controls)
    }

    @ViewBuilder static func menu(_ view: AnyView, item: ItemParams, controls: Controls) -> some View {
        let actions = controls.itemActions?(item) ?? []
        if controls.isEditable && controls.canEdit(item) {
            view.contextMenu {
                ActionMenu(items: actions)
                if !actions.isEmpty && (controls.canRename(item) || controls.canDuplicate(item) || controls.canAddChild(for: item) || controls.canDelete(item)) {
                    Divider()
                }
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

    static func transfer(_ view: AnyView, item: ItemParams, controls: Controls) -> AnyView {
        let canDrag = controls.canDrag?(item) ?? ReferenceTransfer.canDrag(item)
        let withDrag: AnyView

        if canDrag {
            withDrag = AnyView(
                view
                    .contentShape(Rectangle())
                    .onDrag { ReferenceTransfer.provider(for: item) ?? NSItemProvider() }
            )
        }
        else { withDrag = view }

        let types = controls.dropTypes?(item) ?? ReferenceTransfer.dropTypes(for: item)
        guard !types.isEmpty else { return withDrag }

        return AnyView(
            withDrag.onDrop(of: types, isTargeted: nil) { providers in
                controls.onDrop?(providers, item) ?? ReferenceTransfer.handle(providers, target: item)
            }
        )
    }

    static func surfaceTransfer(_ view: AnyView, controls: Controls) -> AnyView {
        guard let target = controls.surfaceDropTarget?() else { return view }
        let types = controls.dropTypes?(target) ?? ReferenceTransfer.dropTypes(for: target)
        guard !types.isEmpty else { return view }

        return AnyView(
            view
                .contentShape(Rectangle())
                .onDrop(of: types, isTargeted: nil) { providers in
                    controls.onDrop?(providers, target) ?? ReferenceTransfer.handle(providers, target: target)
                }
        )
    }
}

private struct CanvasItem: View {
    let item: ItemParams
    let position: CGPoint
    let controls: Controls

    @State private var dragOrigin: CGPoint?

    var body: some View {
        let view = AnyView(ItemIcon(item: item, controls: controls))
        let decorated = Builder.transfer(view, item: item, controls: controls)

        Builder.menu(decorated, item: item, controls: controls)
            .position(position)
            .highPriorityGesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if dragOrigin == nil { dragOrigin = position }
                        guard let dragOrigin else { return }
                        controls.onCanvasPosition?(item, clamped(
                            CGPoint(
                                x: dragOrigin.x + value.translation.width,
                                y: dragOrigin.y + value.translation.height
                            )
                        ))
                    }
                    .onEnded { value in
                        let origin = dragOrigin ?? position
                        controls.onCanvasPosition?(item, clamped(
                            CGPoint(
                                x: origin.x + value.translation.width,
                                y: origin.y + value.translation.height
                            )
                        ))
                        dragOrigin = nil
                    }
            )
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: max(48, point.x), y: max(56, point.y))
    }
}
