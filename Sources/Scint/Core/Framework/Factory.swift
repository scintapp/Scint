import Foundation
import SwiftUI
import UniformTypeIdentifiers
import ScintComponents


struct ItemChrome<Content: View>: View {
    var item: ItemParams
    var controls: Controls
    var model: any Model
    @ViewBuilder var content: Content

    var types: [UTType] { controls.dropTypes?(item) ?? ReferenceTransfer.dropTypes(for: item) }

    @ViewBuilder var dropped: some View {
        if types.isEmpty { content.contentShape(Rectangle()) }
        else {
            content
                .contentShape(Rectangle())
                .onDrop(of: types, isTargeted: nil) { controls.onDrop?($0, item) ?? ReferenceTransfer.handle($0, target: item) }
        }
    }

    @ViewBuilder var dragged: some View {
        if ReferenceTransfer.canDrag(item) { dropped.onDrag { ReferenceTransfer.provider(for: item) ?? NSItemProvider() } }
        else { dropped }
    }

    var body: some View {
        if let palette = controls.itemPalette?(item) { dragged.contextMenu { ActionMenu(model: model, items: palette) } }
        else { dragged }
    }
}

@MainActor struct GroupFactory {
    @ViewBuilder static func build(_ surface: some Surface, _ section: SectionParams, _ controls: Controls) -> some View {
        GroupLayout(title: section.name, footer: nil) {
            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { GroupDivider() }
                build(surface, item, controls)
            }
        }
    }

    @ViewBuilder static func build(_ surface: some Surface, _ item: ItemParams, _ controls: Controls) -> some View {
        let row = GroupRow(label: item.name, description: item.description) {
            Group {
                if let tint = item.tint, !item.image.isEmpty { Iconography.Icon(symbol: item.image, tint: tint) }
                else if let ref = item.ref { Iconography.icon(for: ref) }
                else { Image(systemName: item.image).foregroundStyle(.secondary) }
            }
            .frame(width: 18, height: 18, alignment: .center)
        } trailing: {
            switch item.trailingKind {
                case .toggle:
                    ItemToggle(isOn: item.active) { controls.onToggle?(item) }

                case .load:
                    LoadMenu(count: item.count, items: item.items) { controls.onSelect?($0) }

                case .action:
                    CountButton(count: item.count, label: item.value ?? "Load") { controls.onAction?(item) }

                case .picker:
                    ItemPicker(value: item.value ?? "", items: item.items) { controls.onChange?(item, $0) }
                        .background { Circle().size(width: 20, height: 20, anchor: .center).fill(Style.Background.selection) }

                case .range:
                    ItemRangePicker(value: item.value ?? "", items: item.items) { controls.onChange?(item, $0) }

                case .field:
                    ItemField(value: item.value ?? "") { controls.onValueChange?(item, $0) }

                case .date, .time, .moment:
                    HStack(spacing: 8) {
                        if item.active {
                            ItemDatePicker(value: item.value ?? "", components: item.trailingKind == .time ? [.hourAndMinute] : item.trailingKind == .moment ? [.date, .hourAndMinute] : [.date]) {
                                controls.onValueChange?(item, $0)
                            }
                        }
                        ItemToggle(isOn: item.active) { controls.onToggle?(item) }
                    }

                case .remove:
                    RemoveButton { controls.onAction?(item) }

                default:
                    EmptyView()
            }
        }

        ItemChrome(item: item, controls: controls, model: surface.model) {
            if item.trailingKind == .button { Button { controls.onAction?(item) } label: { row }.buttonStyle(.plain) }
            else if item.trailingKind == nil, item.ref != nil || item.entryId != nil { Button { controls.onSelect?(item) } label: { row }.buttonStyle(.plain) }
            else { row }
        }
    }
}

@MainActor struct ListFactory {
    @ViewBuilder static func build(_ surface: some Surface, _ section: SectionParams, _ controls: Controls) -> some View {
        if section.header {
            let header = AnyView(ListHeader(name: section.name))
            controls.wrapHeader?(header, section) ?? header
        }
        ForEach(section.items) { build(surface, $0, controls).padding(.vertical, 1) }
    }

    @ViewBuilder static func build(_ surface: some Surface, _ item: ItemParams, _ controls: Controls) -> some View {
        if item.isParent {
            let children = item.items.map { child in
                var nested = child
                nested.indent = item.indent + 16
                return nested
            }

            ListLayout(
                name: item.name,
                detail: item.description,
                ref: item.ref,
                image: item.image,
                tint: item.tint,
                count: item.count,
                indent: item.indent,
                isExpanded: surface.isExpanded(item.id),
                selected: controls.selected?(item) ?? false,
                focused: controls.focused?(item) ?? true,
                onSelect: { controls.onSelect?(item) },
                onToggleExpanded: { surface.setExpanded(item.id) },
                rowWrapper: { row in AnyView(ItemChrome(item: item, controls: controls, model: surface.model) { controls.wrapLink?(row, item, 0) ?? row }) }
            ) {
                ForEach(children) { AnyView(build(surface, $0, controls)) }
            }
        } else {
            let link = AnyView(
                ListLink(
                    name: item.name,
                    detail: item.description,
                    ref: item.ref,
                    image: item.image,
                    tint: item.tint,
                    count: item.count,
                    leadingAccessory: controls.itemLeadingAccessory?(item, 0),
                    indent: item.indent,
                    selected: controls.selected?(item) ?? false,
                    focused: controls.focused?(item) ?? true,
                    onSelect: { controls.onSelect?(item) }
                )
            )
            ItemChrome(item: item, controls: controls, model: surface.model) { controls.wrapLink?(link, item, 0) ?? link }
        }
    }
}

@MainActor struct PanelFactory {
    @ViewBuilder static func build(_ surface: some Surface, _ params: Params, _ controls: Controls) -> some View {
        let content = ScrollView {
            VStack(alignment: .leading) {
                if params.header, params.layout == .group, let ref = params.ref {
                    GroupHeader(ref: ref)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.top, GroupMetrics.headerTop)
                        .padding(.bottom, 12)
                }

                ForEach(params.sections) { section in
                    let target = controls.sectionDropTarget?(section)
                    let types = target.map { controls.dropTypes?($0) ?? ReferenceTransfer.dropTypes(for: $0) } ?? []
                    let stack = VStack(spacing: 0) {
                        switch params.layout ?? .list {
                            case .group:
                                GroupFactory.build(surface, section, controls)

                            case .list:
                                ListFactory.build(surface, section, controls)

                            default:
                                EmptyView()
                        }
                    }

                    Group {
                        if let target, !types.isEmpty { stack.onDrop(of: types, isTargeted: nil) { controls.onDrop?($0, target) ?? ReferenceTransfer.handle($0, target: target) } }
                        else { stack }
                    }
                    .padding(.bottom, 16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 8)
        }
        .contentShape(Rectangle())

        if let target = controls.surfaceDropTarget?() {
            content.onDrop(of: controls.dropTypes?(target) ?? ReferenceTransfer.dropTypes(for: target), isTargeted: nil) { controls.onDrop?($0, target) ?? ReferenceTransfer.handle($0, target: target) }
        }
        else { content }
    }
}
