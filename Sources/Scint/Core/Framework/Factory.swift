import Foundation
import SwiftUI
import ScintComponents

//protocol Factory {
//    associatedtype Content: View
//    static func build(_ surface: some Surface, _ params: Params, _ controls: Controls) -> Content
//    func build(_ surface: some Surface, params: PanelParams, controls: Controls) -> Content
//    func build(_ surface: some Surface, params: SectionParams, controls: Controls, layout: Layout?) -> Content
//    func build(_ surface: some Surface, params: ItemParams, controls: Controls, layout: Layout?, indent: CGFloat) -> Content
//}
//
@MainActor struct Factory {
    @ViewBuilder static func build(_ surface: some Surface, _ params: Params, _ controls: Controls) -> some View {
        let target = controls.surfaceDropTarget?()
        let palette = controls.surfacePalette?() ?? []

        let content = ScrollView {
            VStack(alignment: .leading) {
                if params.header, params.layout == .group, let ref = params.ref {
                    GroupHeader(ref: ref)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.top, GroupMetrics.headerTop)
                        .padding(.bottom, 12)
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
                            .padding(.vertical, 1)
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

    @ViewBuilder static func build(_ surface: some Surface, params: ItemParams, controls: Controls, layout: Layout? = nil, indent: CGFloat = 0) -> some View {
        let ref = params.path == nil && params.entryId == nil ? params.ref : nil

        switch layout {
            case .group:
                let row = AnyView(
                    GroupRow(label: params.name, description: params.trailingKind == .value && params.value == nil ? "" : params.description) {
                        Group {
                            if let tint = params.tint, !params.image.isEmpty { Iconography.Icon(symbol: params.image, tint: tint) }
                            else if let ref { Iconography.icon(for: ref) }
                            else { Image(systemName: params.image).foregroundStyle(.secondary) }
                        }
                        .frame(width: 18, height: 18, alignment: .center)
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

            default:
                EmptyView()
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
