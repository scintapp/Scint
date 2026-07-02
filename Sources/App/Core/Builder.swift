import SwiftUI


@MainActor public enum Builder {
    @ViewBuilder static func build<P: Panel>(_ model: AgencyModel, _ panel: P) -> some View {
        let controls = panel.controls(model)
        let params = panel.parameters(model)
        build(panel, controls: controls, params: params, surface: AnyView(build(panel, controls: controls, params: params)))
            .padding(.bottom, 12)
    }

    static func build<P: Panel>(_ panel: P, controls: Controls, params: PanelParams, surface view: AnyView) -> AnyView {
        let transferred: AnyView

        if let target = controls.surfaceDropTarget?() {
            let types = controls.dropTypes?(target) ?? ReferenceTransfer.dropTypes(for: target)
            if types.isEmpty { transferred = view }
            else {
                transferred = AnyView(
                    view
                        .contentShape(Rectangle())
                        .onDrop(of: types, isTargeted: nil) { providers in
                            controls.onDrop?(providers, target) ?? ReferenceTransfer.handle(providers, target: target)
                        }
                )
            }
        } else { transferred = view }

        if let actions = controls.surfaceActions?(), !actions.isEmpty {
            return AnyView(
                transferred
                    .contentShape(Rectangle())
                    .contextMenu { ActionMenu(items: actions) }
            )
        } else { return transferred }
    }

    @ViewBuilder static func build<P: Panel>(_ panel: P, controls: Controls, params: PanelParams) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if params.header == true && params.layout == .group {
                    GroupHeader(title: params.name, description: params.description)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.bottom, 12)
                }

                ForEach(params.components) { component in
                    build(panel, controls: controls, params: params, component: component)
                }
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())

    }

    @ViewBuilder static func build<P: Panel>(_ panel: P, controls: Controls, params: PanelParams, component: ComponentParams) -> some View {
        switch params.layout ?? panel.layout {
            case .group:
                GroupLayout(title: component.name, footer: component.footer) {
                    ForEach(Array(component.items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { GroupDivider() }

                        let row = AnyView(
                            GroupRow(label: item.name) {
                                build(panel, controls: controls, params: params, leading: item)
                            } trailing: {
                                build(panel, controls: controls, params: params, accessory: item)
                            }
                        )

                        let view = item.ref != nil || item.entryId != nil
                        ? AnyView(Button { controls.onSelect?(item) } label: { row }.buttonStyle(.plain))
                        : row

                        build(panel, controls: controls, params: params, view: view, item: item)
                    }
                }
            case .grid:
                VStack(spacing: 0) {
                    if component.header { ListHeader(name: component.name) }
                    GridLayout {
                        ForEach(component.items) { item in
                            let view = AnyView(
                                ItemIcon(
                                    name: item.name,
                                    ref: item.ref,
                                    image: item.image,
                                    tint: item.tint,
                                    focused: controls.focused?(item) ?? false,
                                    onSelect: { controls.onSelect?(item) },
                                    onOpen: { controls.onOpen?(item) }
                                )
                            )

                            build(panel, controls: controls, params: params, view: view, item: item)
                        }
                    }
                }
            case .table:
                VStack(spacing: 0) {
                    if component.header { ListHeader(name: component.name) }
                    TableLayout {
                        ForEach(Array(component.items.enumerated()), id: \.element.id) { index, item in
                            let view = AnyView(
                                TableRow(
                                    title: item.name,
                                    summary: item.description,
                                    time: nil,
                                    status: nil,
                                    count: item.count,
                                    trailingImage: item.trailingImage,
                                    focused: controls.focused?(item) ?? false,
                                    onSelect: { controls.onSelect?(item) }
                                ) {
                                    build(panel, controls: controls, params: params, leading: item)
                                }
                            )

                            build(panel, controls: controls, params: params, view: view, item: item)
                            if index < component.items.count - 1 { Divider() }
                        }
                    }
                }
            case .list:
                VStack(spacing: 0) {
                    if component.header {
                        let header = AnyView(ListHeader(
                            name: component.name,
                            onAdd: controls.canAddInline(sectionId: component.id) ? {
                                controls.onAddItem?(component.id, "")
                            } : nil
                        ))

                        if let wrapHeader = controls.wrapHeader { wrapHeader(header, component) }
                        else { header }
                    }

                    ForEach(component.items) { item in
                        build(panel, controls: controls, params: params, item: item, depth: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 16)
        }
    }

    @ViewBuilder static func build<P: Panel>(_ panel: P, controls: Controls, params: PanelParams, item: ItemParams, depth: Int) -> some View {
        let indent = CGFloat(depth) * 16

        let canExpand: Bool = {
            switch params.nesting ?? .flat {
                case .recursive: return true
                case .single: return depth == 0
                case .flat: return false
            }
        }()

        if item.isParent && canExpand {
            let view = AnyView(
                ListLayout(
                    name: item.name,
                    ref: item.path == nil && item.entryId == nil ? item.ref : nil,
                    image: item.image,
                    tint: item.tint,
                    trailingImage: item.trailingImage,
                    count: item.count,
                    leadingAccessory: controls.sectionLeadingAccessory?(item, depth),
                    accessory: controls.sectionAccessory?(item, depth),
                    indent: indent,
                    isExpanded: panel.isExpanded(item.id),
                    selected: controls.selected?(item) ?? false,
                    onSelect: { controls.onSelect?(item) },
                    onToggleExpanded: { panel.setExpanded(item.id) }
                ) {
                    ForEach(item.items) { child in
                        build(panel, controls: controls, params: params, item: child, depth: depth + 1)
                    }
                }
            )

            let wrapped = controls.wrapSection?(view, item, depth) ?? view
            build(panel, controls: controls, params: params, view: wrapped, item: item)
        } else {
            let view = AnyView(
                ListLink(
                    name: item.name,
                    ref: item.path == nil && item.entryId == nil ? item.ref : nil,
                    image: item.image,
                    tint: item.tint,
                    trailingImage: item.trailingImage,
                    count: item.count,
                    leadingAccessory: controls.itemLeadingAccessory?(item, depth),
                    accessory: controls.itemAccessory?(item, depth),
                    indent: indent,
                    selected: controls.selected?(item) ?? false,
                    onSelect: { controls.onSelect?(item) }
                )
            )

            let wrapped = controls.wrapLink?(view, item, depth) ?? view
            build(panel, controls: controls, params: params, view: wrapped, item: item)
        }
    }

    static func build<P: Panel>(_ panel: P, controls: Controls, params: PanelParams, view: AnyView, item: ItemParams) -> AnyView {
        let canDrag = controls.canDrag?(item) ?? ReferenceTransfer.canDrag(item)
        let draggable: AnyView

        if canDrag {
            draggable = AnyView(
                view
                    .contentShape(Rectangle())
                    .onDrag { ReferenceTransfer.provider(for: item) ?? NSItemProvider() }
            )
        } else {
            draggable = view
        }

        let types = controls.dropTypes?(item) ?? ReferenceTransfer.dropTypes(for: item)
        let transferred: AnyView

        if types.isEmpty {
            transferred = draggable
        } else {
            transferred = AnyView(
                draggable.onDrop(of: types, isTargeted: nil) { providers in
                    controls.onDrop?(providers, item) ?? ReferenceTransfer.handle(providers, target: item)
                }
            )
        }

        let actions = controls.itemActions?(item) ?? []

        if controls.isEditable && controls.canEdit(item) {
            return AnyView(
                transferred.contextMenu {
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
            )
        } else {
            return transferred
        }
    }

    @ViewBuilder static func build<P: Panel>(_ panel: P, controls: Controls, params: PanelParams, leading item: ItemParams) -> some View {
        if let ref = item.ref, item.path == nil && item.entryId == nil {
            Iconography.icon(for: ref)
        } else if let tint = item.tint {
            Iconography.Icon(symbol: item.image, tint: tint)
        } else {
            Image(systemName: item.image)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder static func build<P: Panel>(_ panel: P, controls: Controls, params: PanelParams, accessory item: ItemParams) -> some View {
        switch item.trailingKind {
            case .toggle:
                GroupToggle(isOn: false) { controls.onToggle?(item) }
            case .load:
                GroupLoader(
                    count: item.count,
                    items: item.items.map {
                        GroupPickerItem(
                            id: $0.id,
                            name: $0.name,
                            image: $0.image,
                            ref: $0.ref,
                            active: $0.active
                        )
                    },
                    onPick: { id in
                        if let candidate = item.items.first(where: { $0.id == id }) {
                            controls.onSelect?(candidate)
                        }
                    }
                )
            case .action:
                GroupCountButton(count: item.count) { controls.onAction?(item) }
            case .value:
                Text(item.description)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            default:
                EmptyView()
        }
    }
}
