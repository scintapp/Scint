import SwiftUI
import ScintRuntime
import ScintComponents


@MainActor struct ListFactory {
    @ViewBuilder static func build(_ surface: some Surface, _ section: SectionParams, _ controls: Controls) -> some View {
        if section.header {
            let header = AnyView(ListHeader(name: section.name))
            controls.wrapHeader?(header, section) ?? header
        }
        
        ForEach(section.items) {
            build(surface, $0, controls)
                .padding(.vertical, 1)
        }
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
                rowWrapper: { row in AnyView(ViewContainer(item: item, controls: controls, model: surface.model) { controls.wrapLink?(row, item, 0) ?? row }) }
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
            ViewContainer(item: item, controls: controls, model: surface.model) { controls.wrapLink?(link, item, 0) ?? link }
        }
    }
}
