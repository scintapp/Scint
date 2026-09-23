import Foundation
import SwiftUI
import ScintComponents


@MainActor enum Factory {
    @ViewBuilder static func build(_ surface: some Surface, _ params: Params, _ controls: Controls) -> some View {
        if let panel = params.panel { build(surface, params: panel, controls: controls) }
        else {
            let target = controls.surfaceDropTarget?()
            let palette = controls.surfacePalette?() ?? []

            let content = ScrollView {
                VStack(alignment: .leading) {
                    if params.header, params.layout == .group, let ref = params.ref {
                        GroupHeader(ref: ref)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.top, GroupMetrics.headerTop)
                    }

                    ForEach(params.sections) { section in
                        build(surface, params: section, controls: controls, layout: section.layout ?? params.layout ?? .list)
                            .padding(.bottom, 16)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)
            }
            .contentShape(Rectangle())

            let dropped = target.map { target in
                AnyView(
                    content.onDrop(of: controls.dropTypes?(target) ?? ReferenceTransfer.dropTypes(for: target), isTargeted: nil) { providers in
                        controls.onDrop?(providers, target) ?? ReferenceTransfer.handle(providers, target: target)
                    }
                )
            } ?? AnyView(content)

            if palette.isEmpty { dropped }
            else { dropped.contextMenu { ActionMenu(model: surface.model, items: palette) } }
        }
    }

    @ViewBuilder static func build(_ surface: some Surface, params: PanelParams, controls: Controls) -> some View {
        let panel = surface.panel
        let sections = (controls.results?(panel.state.query) ?? []).compactMap { group -> SectionParams? in
            guard !group.results.isEmpty else { return nil }
            return SectionParams(id: group.id.description, name: group.name, header: !group.name.isEmpty, image: group.image, items: group.results.map {
                let icon = Iconography.icon(for: $0.ref)
                return ItemParams(ref: $0.ref, name: $0.name, image: icon.symbol, tint: icon.tint.bright, description: $0.description)
            })
        }

        let items = sections.flatMap(\.items)
        let cursor = panel.state.cursor ?? items.first?.id
        let selection = items.first { $0.id == cursor }
        let detail = panel.state.detail ? selection.flatMap { controls.detail?($0) } : nil

        let move: (Int) -> KeyPress.Result = { delta in
            guard !items.isEmpty else { return .handled }
            let current = items.firstIndex { $0.id == cursor } ?? 0
            panel.state.cursor = items[(current + delta + items.count) % items.count].id
            return .handled
        }

        let change: (Int) -> Void = { index in
            guard params.items.indices.contains(index) else { return }
            let target = params.items[index]
            if let surface = target.key { panel.state.surface = surface }
            panel.state.query = ""
            panel.state.cursor = nil
            controls.onChange?(params.selection ?? target, target)
        }

        PanelView {
            if let detail {
                PanelDetail(params: detail) {
                    ForEach(detail.sections) { build(surface, params: $0, controls: controls) }
                }
            } else {
                if let input = params.input {
                    PanelInput(
                        value: Binding(
                            get: { panel.state.query },
                            set: { panel.state.query = $0; controls.onValueChange?(input, $0) }
                        ),
                        image: input.image,
                        placeholder: input.name,
                        onUpArrow: { move(-1) },
                        onDownArrow: { move(+1) },
                        onReturn: {
                            if let selection { controls.onSelect?(selection) }
                            return .handled
                        },
                        onTab: {
                            guard selection != nil, controls.detail != nil else { return .ignored }
                            panel.state.detail.toggle()
                            return .handled
                        }
                    )
                }

                if !params.items.isEmpty {
                    PanelModes(items: params.items, selection: params.selection) { target in
                        change(params.items.firstIndex { $0.id == target.id } ?? 0)
                    }
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(sections) { build(surface, params: $0, controls: controls) }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
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
            if params.pinnable { PanelPin(pinned: panel.state.pinned) { panel.state.pinned.toggle() } }
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

    // Section. Stamps each item with the layout, nesting and depth it was resolved with.
    @ViewBuilder static func build(_ surface: some Surface, params: SectionParams, controls: Controls, layout: Layout? = nil) -> some View {
        let target = controls.sectionDropTarget?(params)
        let types = target.map { controls.dropTypes?($0) ?? ReferenceTransfer.dropTypes(for: $0) } ?? []

        let layout = params.layout ?? layout
        let content = VStack(spacing: 0) {
            switch layout {
                case .group:
                    GroupLayout(title: params.name, footer: params.footer) {
                        ForEach(Array(params.items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { GroupDivider() }
                            build(surface, params: item, controls: controls, layout: .group)
                        }
                    }

                case .list:
                    if params.header {
                        let header = AnyView(
                            ListHeader(
                                name: params.name,
                                onAdd: controls.canAddInline(sectionId: params.id) ? { controls.onAddItem?(params.id, "") } : nil
                            )
                        )
                        controls.wrapHeader?(header, params) ?? header
                    }

                    ForEach(params.items) {
                        build(surface, params: $0, controls: controls, layout: .list)
                    }

                // No layout is panel chrome: the panel stamps nothing onto its results.
                case .none:
                    if !params.items.isEmpty {
                        if params.header && !params.name.isEmpty { PanelHeader(name: params.name) }
                        ForEach(params.items) { build(surface, params: $0, controls: controls) }
                    }

                default:
                    EmptyView()
            }
        }

        if let target, !types.isEmpty {
            content.onDrop(of: types, isTargeted: nil) { providers in
                controls.onDrop?(providers, target) ?? ReferenceTransfer.handle(providers, target: target)
            }
        } else {
            content
        }
    }

    // Item. A parent's children are a section, which is where this recurses.
    @ViewBuilder static func build(_ surface: some Surface, params: ItemParams, controls: Controls, layout: Layout? = nil, indent: CGFloat = 0) -> some View {
        let ref = params.path == nil && params.entryId == nil ? params.ref : nil

        switch layout {
            case .group:
                let row = AnyView(
                    GroupRow(label: params.name, description: params.trailingKind == .value && params.value == nil ? "" : params.description) {
                        if let tint = params.tint, !params.image.isEmpty { Iconography.Icon(symbol: params.image, tint: tint) }
                        else if let ref { Iconography.icon(for: ref) }
                        else { Image(systemName: params.image).foregroundStyle(.secondary) }
                    } trailing: {
                        switch params.trailingKind {
                            case .toggle:
                                ItemToggle(isOn: params.active) { controls.onToggle?(params) }

                            case .load:
                                LoadMenu(count: params.count, items: params.items) { controls.onSelect?($0) }

                            case .action:
                                CountButton(count: params.count, label: params.value ?? "Load") { controls.onAction?(params) }

                            case .value:
                                Text(params.value ?? params.description)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)

                            case .picker:
                                ItemPicker(value: params.value ?? "", items: params.items) { controls.onChange?(params, $0) }
                                    .background { Circle().size(width: 20, height: 20, anchor: .center).fill(Style.Background.selection) }

                            case .range:
                                ItemRangePicker(value: params.value ?? "", items: params.items) { controls.onChange?(params, $0) }

                            case .field:
                                ItemField(value: params.value ?? "") { controls.onValueChange?(params, $0) }

                            // A date argument is absent or set, not false or true, so the switch is that
                            // distinction and the field beside it only appears once the switch is on.
                            case .date, .time, .moment:
                                HStack(spacing: 8) {
                                    if params.active {
                                        ItemDatePicker(value: params.value ?? "", components: params.trailingKind == .time ? [.hourAndMinute] : params.trailingKind == .moment ? [.date, .hourAndMinute] : [.date]) {
                                            controls.onValueChange?(params, $0)
                                        }
                                    }
                                    ItemToggle(isOn: params.active) { controls.onToggle?(params) }
                                }

                            case .remove:
                                RemoveButton { controls.onAction?(params) }

                            default:
                                EmptyView()
                        }
                    }
                )

                if params.trailingKind == .button {
                    build(surface, Button(action: { controls.onAction?(params) }) { row }.buttonStyle(.plain), params: params, controls: controls)
                } else if (params.ref != nil || params.entryId != nil) && params.trailingKind == nil {
                    build(surface, Button(action: { controls.onSelect?(params) }) { row }.buttonStyle(.plain), params: params, controls: controls)
                } else {
                    build(surface, row, params: params, controls: controls)
                }

            case .list where params.isParent:
                ListLayout(
                    name: params.name,
                    detail: params.description,
                    ref: ref,
                    image: params.image,
                    tint: params.tint,
                    trailingImage: params.trailingImage,
                    count: params.count,
                    leadingAccessory: controls.sectionLeadingAccessory?(params, 0),
                    accessory: controls.sectionAccessory?(params, 0),
                    indent: indent,
                    isExpanded: surface.isExpanded(params.id),
                    selected: controls.selected?(params) ?? false,
                    focused: controls.focused?(params) ?? true,
                    onSelect: { controls.onSelect?(params) },
                    onToggleExpanded: { surface.setExpanded(params.id) },
                    rowWrapper: { AnyView(build(surface, controls.wrapSection?($0, params, 0) ?? controls.wrapLink?($0, params, 0) ?? $0, params: params, controls: controls)) }
                ) {
                    ForEach(params.items) { child in
                        AnyView(build(surface, params: child, controls: controls, layout: .list, indent: indent + 16))
                    }
                }

            case .list:
                let link = AnyView(
                    ListLink(
                        name: params.name,
                        detail: params.description,
                        ref: ref,
                        image: params.image,
                        tint: params.tint,
                        trailingImage: params.trailingImage,
                        count: params.count,
                        leadingAccessory: controls.itemLeadingAccessory?(params, 0),
                        accessory: controls.itemAccessory?(params, 0),
                        indent: indent,
                        selected: controls.selected?(params) ?? false,
                        focused: controls.focused?(params) ?? true,
                        onSelect: { controls.onSelect?(params) }
                    )
                )
                build(surface, controls.wrapLink?(link, params, 0) ?? link, params: params, controls: controls)

            // No layout is panel chrome, as above. Panel rows carry no transfer affordances.
            default:
                PanelRow(params: params, selected: controls.selected?(params) ?? false) {
                    if params.trailingKind == .button { controls.onAction?(params) }
                    else {
                        surface.panel.state.cursor = params.id
                        controls.onSelect?(params)
                    }
                }
                .id(params.id)
        }
    }

    // Controls. Everything Controls affords a row: drag, drop, and its context menu.
    // Scoped to a row, never to a row plus its expanded children.
    @ViewBuilder static func build(_ surface: some Surface, _ view: some View, params: ItemParams, controls: Controls) -> some View {
        let types = controls.dropTypes?(params) ?? ReferenceTransfer.dropTypes(for: params)
        let palette = controls.itemPalette?(params) ?? []
        let editable = controls.isEditable && controls.canEdit(params)
        let draggable = controls.canDrag?(params) ?? ReferenceTransfer.canDrag(params)

        let row = AnyView(view.contentShape(Rectangle()))

        let dropped = types.isEmpty ? row : AnyView(
            row.onDrop(of: types, isTargeted: nil) { providers in
                controls.onDrop?(providers, params) ?? ReferenceTransfer.handle(providers, target: params)
            }
        )

        let dragged = draggable ? AnyView(dropped.onDrag { ReferenceTransfer.provider(for: params) ?? NSItemProvider() }) : dropped

        if editable {
            dragged.contextMenu {
                ActionMenu(model: surface.model, items: palette)
                if !palette.isEmpty && (controls.canRename(params) || controls.canDuplicate(params) || controls.canAddChild(for: params) || controls.canDelete(params)) { Divider() }
                ItemContextMenu(
                    params: params,
                    onRename: controls.canRename(params) ? { controls.onRename?(params.id, params.name) } : nil,
                    onDuplicate: controls.canDuplicate(params) ? { controls.onDuplicate?(params.id) } : nil,
                    onDelete: controls.canDelete(params) ? { controls.onDelete?(params.id) } : nil,
                    onAddChild: controls.canAddChild(for: params) ? { controls.onAddItem?(params.id, "") } : nil
                )
            }
        } else {
            dragged
        }
    }
}
