import SwiftUI
import Foundation


@MainActor enum Factory {
    @ViewBuilder static func build(_ surface: some Surface, _ params: Params, _ controls: Controls) -> some View {
        if let panel = params.panel {  build(surface.panel, panel, controls) }
        else {
            let nesting = params.nesting ?? .flat
            let layout = params.layout ?? .list

            let view = ScrollView {
                VStack(alignment: .leading) {
                    build(params)
                    ForEach(params.sections) { component in
                        build(surface, controls: controls, params: component, layout: layout, nesting: nesting)
                            .padding(.bottom, 16)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)
            }

            build(surface, controls, view: AnyView(view))
        }
    }

    @ViewBuilder static func build(_ surface: some Surface, controls: Controls, params: SectionParams, layout: Layout, nesting: Nesting) -> some View {
        switch layout {
            case .group:
                let view = AnyView(
                    GroupLayout(title: params.name, footer: params.footer) {
                        ForEach(Array(params.items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { GroupDivider() }
                            let description = item.trailingKind == .value && item.value == nil ? "" : item.description

                            let row = AnyView(
                                GroupRow(label: item.name, description: description) {
                                    build(item)
                                } trailing: {
                                    if item.trailingKind == .picker {
                                        build(controls, params: item)
                                            .background {
                                                Circle()
                                                    .size(width: 20, height: 20, anchor: .center)
                                                    .fill(Style.Background.control)
                                            }
                                    } else {
                                        build(controls, params: item)
                                    }
                                }
                            )

                            let view = AnyView(
                                Group {
                                    if item.trailingKind == .button {
                                        Button(action: { controls.onAction?(item) }) { row }
                                            .buttonStyle(.plain)
                                    } else if (item.ref != nil || item.entryId != nil) && item.trailingKind == nil {
                                        Button(action: { controls.onSelect?(item) }) { row }
                                            .buttonStyle(.plain)
                                    } else {
                                        row
                                    }
                                }
                            )
                            build(surface, controls, params: item, view: view)
                        }
                    }
                )
                build(surface, controls, params: params, view: view)

            case .grid:
                let view = AnyView(
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

                                build(surface, controls, params: item, view: view)
                            }
                        }
                    }
                )
                build(surface, controls, params: params, view: view)

            case .table:
                let view = AnyView(EmptyView())
                build(surface, controls, params: params, view: view)

            case .list:
                let view = AnyView(
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
                )
                build(surface, controls, params: params, view: view)
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
                    detail: params.description,
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
                    focused: controls.focused?(params) ?? true,
                    onSelect: { controls.onSelect?(params) },
                    onToggleExpanded: { surface.setExpanded(params.id) },
                    rowWrapper: { row in
                        let wrapped = controls.wrapSection?(row, params, depth) ?? row
                        return build(surface, controls, params: params, view: wrapped)
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
                    detail: params.description,
                    ref: params.path == nil && params.entryId == nil ? params.ref : nil,
                    image: params.image,
                    tint: params.tint,
                    trailingImage: params.trailingImage,
                    count: params.count,
                    leadingAccessory: controls.itemLeadingAccessory?(params, depth),
                    accessory: controls.itemAccessory?(params, depth),
                    indent: indent,
                    selected: controls.selected?(params) ?? false,
                    focused: controls.focused?(params) ?? true,
                    onSelect: { controls.onSelect?(params) }
                )
            )

            let wrapped = controls.wrapLink?(view, params, depth) ?? view
            build(surface, controls, params: params, view: wrapped)
        }
    }

    @ViewBuilder static func build(_ controls: Controls, params: ItemParams) -> some View {
        switch params.trailingKind {
            case .toggle:
                ItemToggle(isOn: params.active) { controls.onToggle?(params) }

            case .load:
                LoadMenu(
                    count: params.count,
                    items: params.items,
                    onPick: { controls.onSelect?($0) }
                )

            case .action:
                CountButton(count: params.count, label: params.value ?? "Load") {
                    controls.onAction?(params)
                }

            case .value:
                Text(params.value ?? params.description)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

            case .picker:
                ItemPicker(value: params.value ?? "", items: params.items) { controls.onChange?(params, $0) }

            case .range:
                ItemRangePicker(value: params.value ?? "", items: params.items) {
                    controls.onChange?(params, $0)
                }

            case .field:
                ItemField(value: params.value ?? "") {
                    controls.onValueChange?(params, $0)
                }

            case .date:
                ItemDatePicker(value: params.value ?? "") {
                    controls.onValueChange?(params, $0)
                }

            case .remove:
                RemoveButton { controls.onAction?(params) }

            case .button:
                EmptyView()

            default:
                EmptyView()
        }
    }

    @ViewBuilder static func build(_ params: Params) -> some View {
        if params.header == true {
            switch params.layout {
                case .grid:
                    EmptyView()

                case .group:
                    if let ref = params.ref {
                        GroupHeader(ref: ref)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.top, GroupMetrics.headerTop)
                    }

                case .list:
                    EmptyView()

                case .table:
                    EmptyView()

                default:
                    EmptyView()
            }
        }
    }

    @ViewBuilder static func build(_ item: ItemParams) -> some View {
        if let tint = item.tint, !item.image.isEmpty {
            Iconography.Icon(symbol: item.image, tint: tint)
        } else if let ref = item.ref, item.path == nil && item.entryId == nil {
            Iconography.icon(for: ref)
        } else {
            Image(systemName: item.image).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder static func build(_ panel: any Panel, _ params: SectionParams, _ controls: Controls) -> some View {
        if !params.items.isEmpty {
            if params.header && !params.name.isEmpty { PanelHeader(name: params.name) }
            ForEach(params.items) { item in
                build(panel, item, controls)
            }
        }
    }

    @ViewBuilder static func build(_ panel: any Panel, _ params: ItemParams, _ controls: Controls) -> some View {
        PanelRow(params: params, selected: controls.selected?(params) ?? false) {
            if params.trailingKind == .button { controls.onAction?(params) }
            else {
                panel.state.cursor = params.id
                controls.onSelect?(params)
            }
        }
        .id(params.id)
    }
}

extension Factory {
    static func build(_ surface: some Surface, _ controls: Controls, view: AnyView) -> AnyView {
        if let target = controls.surfaceDropTarget?() {
            let types = controls.dropTypes?(target) ?? ReferenceTransfer.dropTypes(for: target)
            if !types.isEmpty {
                let result = view
                    .contentShape(Rectangle())
                    .onDrop(of: types, isTargeted: nil) { providers in
                        controls.onDrop?(providers, target) ?? ReferenceTransfer.handle(providers, target: target)
                    }
                return AnyView(result)
            }
        }

        if let palette = controls.surfacePalette?(), !palette.isEmpty {
            let result = view
                .contentShape(Rectangle())
                .contextMenu { ActionMenu(model: surface.model, items: palette) }
            return AnyView(result)
        }

        return AnyView(view)
    }

    static func build(_ surface: some Surface, _ controls: Controls, params: SectionParams, view: AnyView) -> AnyView {
        guard let target = controls.sectionDropTarget?(params) else { return view }
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

    static func build(_ surface: some Surface, _ controls: Controls, params: ItemParams, view: AnyView) -> AnyView {
        let canDrag = controls.canDrag?(params) ?? ReferenceTransfer.canDrag(params)
        let itemPalette = controls.itemPalette?(params) ?? []
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
                    ActionMenu(model: surface.model, items: itemPalette)
                    if !itemPalette.isEmpty && (controls.canRename(params) || controls.canDuplicate(params) || controls.canAddChild(for: params) || controls.canDelete(params)) { Divider() }
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

    static func build(_ panel: any Panel, _ params: PanelParams, _ controls: Controls) -> some View {
        let components = build(controls.results?(panel.state.query) ?? [])
        let items = components.flatMap(\.items)
        let cursor = panel.state.cursor ?? items.first?.id

        func move(_ delta: Int) {
            guard !items.isEmpty else { return }
            let current = items.firstIndex { $0.id == cursor } ?? 0
            panel.state.cursor = items[(current + delta + items.count) % items.count].id
        }

        let selection = items.first { $0.id == cursor }
        let detail = panel.state.detail ? selection.flatMap { controls.detail?($0) } : nil

        func commit() {
            guard let selection else { return }
            controls.onSelect?(selection)
        }

        func lens() -> KeyPress.Result {
            guard selection != nil, controls.detail != nil else { return .ignored }
            panel.state.detail.toggle()
            return .handled
        }

        func change(_ target: ItemParams) {
            if let mode = target.key { panel.state.surface = mode }
            panel.state.query = ""
            panel.state.cursor = nil
            controls.onChange?(params.selection ?? target, target)
        }

        func change(_ index: Int) {
            guard params.items.indices.contains(index) else { return }
            change(params.items[index])
        }

        func cycle() -> KeyPress.Result {
            guard params.items.count > 1 else { return .ignored }
            let current = params.items.firstIndex { $0.id == params.selection?.id } ?? 0
            change((current + 1) % params.items.count)
            return .handled
        }

        return PanelView {
            if let detail {
                PanelDetail(params: detail) {
                    ForEach(detail.sections) { component in
                        build(panel, component, controls)
                    }
                }
            } else {
                if let input = params.input {
                    PanelInput(
                        value: Binding(
                            get: { panel.state.query },
                            set: {
                                panel.state.query = $0
                                controls.onValueChange?(input, $0)
                            }
                        ),
                        image: input.image,
                        placeholder: input.name,
                        onUpArrow: { move(-1); return .handled },
                        onDownArrow: { move(+1); return .handled },
                        onReturn: { commit(); return .handled },
                        onTab: lens
                    )
                }

                if !params.items.isEmpty {
                    PanelModes(items: params.items, selection: params.selection) { target in
                        change(target)
                    }
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(components) { component in
                                build(panel, component, controls)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                    .scrollEdgeEffectStyle(.soft, for: .vertical)
                    .onChange(of: cursor) { _, id in
                        guard let id else { return }
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if params.pinnable {
                PanelPin(pinned: panel.state.pinned) { panel.state.pinned.toggle() }
            }
        }
        .environment(\.panelCursor, cursor)
        .onReceive(NotificationCenter.default.publisher(for: .scintPanelEscape)) { escape in
            guard panel.state.detail else { return }
            (escape.object as? PanelEscapeEvent)?.handled = true
            panel.state.detail = false
        }
        .onChange(of: panel.state.query) { _, _ in panel.state.cursor = nil }
        .onChange(of: params.selection?.id) { _, _ in panel.state.cursor = nil }
        .background { PanelShortcuts(count: params.items.count) { change($0) } }
    }

    static func build(_ groups: [ResultGroup]) -> [SectionParams] {
        groups.compactMap { group in
            guard !group.results.isEmpty else { return nil }
            return SectionParams(
                id: group.id.description,
                name: group.name,
                header: !group.name.isEmpty,
                image: group.image,
                items: group.results.map { result in
                    let icon = Iconography.icon(for: result.ref)
                    return ItemParams(
                        ref: result.ref,
                        name: result.name,
                        image: icon.symbol,
                        tint: icon.tint,
                        description: result.description
                    )
                }
            )
        }
    }
}

