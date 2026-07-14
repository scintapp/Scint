import SwiftUI
import Foundation


@MainActor public enum Builder {
    @ViewBuilder static func build(_ surface: some Surface, _ params: Params, _ controls: Controls) -> some View {
        let nesting = params.nesting ?? .flat
        let layout = params.layout ?? .list

        build(
            controls,
            view: AnyView(
                ScrollView {
                    Color.clear.frame(height: 8)
                    VStack(alignment: .leading) {
                        build(params: params)

                        ForEach(params.components) { component in
                            build(surface,
                                  controls: controls,
                                  params: component,
                                  layout: layout,
                                  nesting: nesting
                            )
                            .padding(.bottom, 16)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 8)
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        )
    }

    @ViewBuilder static func build(params: Params) -> some View {
        if params.header == true {
            switch params.layout {
                case .grid:
                    EmptyView()

                case .group:
                    GroupHeader(ref: params.ref, title: params.name, description: params.description)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.bottom, 12)

                case .list:
                    EmptyView()

                case .table:
                    EmptyView()

                default:
                    EmptyView()
            }
        }
    }

    @ViewBuilder static func build(_ surface: some Surface, controls: Controls, params: ComponentParams, layout: Layout, nesting: Nesting) -> some View {
        switch layout {
            case .group:
                GroupLayout(title: params.name, footer: params.footer) {
                    ForEach(Array(params.items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { GroupDivider() }

                        let row = AnyView(
                            GroupRow(
                                label: item.name,
                                description: item.trailingKind == .value && item.value == nil ? "" : item.description
                            ) {
                                build(item)
                            } trailing: {
                                build(controls, params: item)
                            }
                        )

                        let selectable = (item.ref != nil || item.entryId != nil)
                            && item.trailingKind == nil
                        let view = selectable
                            ? AnyView(Button { controls.onSelect?(item) } label: { row }.buttonStyle(.plain))
                            : row

                        build(controls, params: item, view: view)
                    }
                }

            case .grid:
                VStack(spacing: 0) {
                    if params.header { ListHeader(name: params.name) }
                    GridLayout {
                        ForEach(params.items) { item in
                            let view = AnyView(
                                GridIcon(
                                    name: item.name,
                                    ref: item.ref,
                                    image: item.image,
                                    tint: item.tint,
                                    focused: controls.focused?(item) ?? false,
                                    onSelect: { controls.onSelect?(item) },
                                    onOpen: { controls.onOpen?(item) }
                                )
                            )

                            build(controls, params: item, view: view)
                        }
                    }
                }

            case .table:
                VStack(spacing: 0) {
                    if params.header { ListHeader(name: params.name) }
                    TableLayout {
                        ForEach(Array(params.items.enumerated()), id: \.element.id) { index, item in
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
                                    build(item)
                                }
                            )

                            build(controls, params: item, view: view)
                            if index < params.items.count - 1 { Divider() }
                        }
                    }
                }

            case .list:
                VStack(spacing: 0) {
                    if params.header {
                        let header = AnyView(
                            ListHeader(
                                name: params.name,
                                onAdd: controls.canAddInline(sectionId: params.id)
                                ? { controls.onAddItem?(params.id, "") }
                                : nil
                            )
                        )

                        if let wrapHeader = controls.wrapHeader { wrapHeader(header, params) }
                        else { header }
                    }

                    ForEach(params.items) { item in
                        build(surface, controls: controls, params: item, nesting: nesting, depth: 0)
                    }
                }
        }
    }

    @ViewBuilder static func build(_ surface: some Surface, controls: Controls, params: ItemParams, nesting: Nesting, depth: Int) -> some View {
        let indent = CGFloat(depth) * 16

        let canExpand: Bool = {
            switch nesting {
                case .recursive: return true
                case .single: return depth == 0
                case .flat: return false
            }
        }()

        if params.isParent && canExpand {
            let view = AnyView(
                ListLayout(
                    name: params.name,
                    ref: params.path == nil && params.entryId == nil ? params.ref : nil,
                    image: params.image,
                    tint: params.tint,
                    trailingImage: params.trailingImage,
                    count: params.count,
                    leadingAccessory: controls.sectionLeadingAccessory?(params, depth),
                    accessory: controls.sectionAccessory?(params, depth),
                    indent: indent,
                    isExpanded: surface.isExpanded(params.id),
                    selected: controls.selected?(params) ?? false,
                    onSelect: { controls.onSelect?(params) },
                    onToggleExpanded: { surface.setExpanded(params.id) },
                    rowWrapper: { row in
                        let wrapped = controls.wrapSection?(row, params, depth) ?? row
                        return build(controls, params: params, view: wrapped)
                    }
                ) {
                    ForEach(params.items) { child in
                        build(surface, controls: controls, params: child, nesting: nesting, depth: depth + 1)
                    }
                }
            )
            view
        } else {
            let view = AnyView(
                ListLink(
                    name: params.name,
                    ref: params.path == nil && params.entryId == nil ? params.ref : nil,
                    image: params.image,
                    tint: params.tint,
                    trailingImage: params.trailingImage,
                    count: params.count,
                    leadingAccessory: controls.itemLeadingAccessory?(params, depth),
                    accessory: controls.itemAccessory?(params, depth),
                    indent: indent,
                    selected: controls.selected?(params) ?? false,
                    onSelect: { controls.onSelect?(params) }
                )
            )

            let wrapped = controls.wrapLink?(view, params, depth) ?? view
            build(controls, params: params, view: wrapped)
        }
    }

    @ViewBuilder static func build(_ controls: Controls, params: ItemParams) -> some View {
        switch params.trailingKind {
            case .toggle:
                GroupToggle(isOn: false) { controls.onToggle?(params) }

            case .load:
                LoaderMenu(
                    count: params.count,
                    items: params.items,
                    onPick: { controls.onSelect?($0) }
                )

            case .action:
                GroupCountButton(count: params.count, label: params.value ?? "Load") {
                    controls.onAction?(params)
                }

            case .value:
                Text(params.value ?? params.description)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

            default:
                EmptyView()
        }
    }

    @ViewBuilder static func build(_ item: ItemParams) -> some View {
        if let ref = item.ref, item.path == nil && item.entryId == nil { Iconography.icon(for: ref) }
        else if let tint = item.tint { Iconography.Icon(symbol: item.image, tint: tint) }
        else { Image(systemName: item.image) .foregroundStyle(.secondary) }
    }
}

extension Builder {
    static func build(_ controls: Controls, view: AnyView) -> AnyView {
        var result = view

        if let target = controls.surfaceDropTarget?() {
            let types = controls.dropTypes?(target) ?? ReferenceTransfer.dropTypes(for: target)
            if !types.isEmpty {
                result = AnyView(
                    result
                        .contentShape(Rectangle())
                        .onDrop(of: types, isTargeted: nil) { providers in
                            controls.onDrop?(providers, target) ?? ReferenceTransfer.handle(providers, target: target)
                        }
                )
            }
        }

        if let actions = controls.surfaceActions?(), !actions.isEmpty {
            result = AnyView(
                result
                    .contentShape(Rectangle())
                    .contextMenu { ActionMenu(items: actions) }
            )
        }

        return result
    }

    static func build(_ controls: Controls, params: ItemParams, view: AnyView) -> AnyView {
        let canDrag = controls.canDrag?(params) ?? ReferenceTransfer.canDrag(params)
        let itemActions = controls.itemActions?(params) ?? []
        let dropTypes = controls.dropTypes?(params) ?? ReferenceTransfer.dropTypes(for: params)
        var result = view

        if canDrag {
            result = AnyView(
                result
                    .contentShape(Rectangle())
                    .onDrag { ReferenceTransfer.provider(for: params) ?? NSItemProvider() }
            )
        }

        if !dropTypes.isEmpty {
            result = AnyView(
                result.onDrop(of: dropTypes, isTargeted: nil) { providers in
                    controls.onDrop?(providers, params) ?? ReferenceTransfer.handle(providers, target: params)
                }
            )
        }

        if controls.isEditable && controls.canEdit(params) {
            result = AnyView(
                result.contextMenu {
                    ActionMenu(items: itemActions)
                    if !itemActions.isEmpty && (controls.canRename(params) || controls.canDuplicate(params) || controls.canAddChild(for: params) || controls.canDelete(params)) { Divider() }
                    ItemContextMenu(
                        params: params,
                        onRename: controls.canRename(params) ? { controls.onRename?(params.id, params.name) } : nil,
                        onDuplicate: controls.canDuplicate(params) ? { controls.onDuplicate?(params.id) } : nil,
                        onDelete: controls.canDelete(params) ? { controls.onDelete?(params.id) } : nil,
                        onAddChild: controls.canAddChild(for: params) ? { controls.onAddItem?(params.id, "") } : nil
                    )
                }
            )
        }

        return result
    }
}
