import SwiftUI
import ScintRuntime
import ScintComponents


@MainActor struct TableFactory {
    static func build(_ surface: some Surface, _ section: SectionParams, _ controls: Controls) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(section.sections) { group in
                if group.header { TableHeader(name: group.name) }

                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { TableDivider() }
                    build(surface, item, controls)
                }
            }
        }
    }

    @ViewBuilder static func build(_ surface: some Surface, _ item: ItemParams, _ controls: Controls) -> some View {
        let row = AnyView(
            TableLayout(
                time: item.value,
                name: item.name,
                detail: item.description,
                done: item.trailingKind == .toggle ? item.active : nil,
                origin: item.origin.map { ($0.descriptor.name, Iconography.icon(for: $0, size: 12)) },
                expandable: item.isParent,
                isExpanded: surface.isExpanded(item.id),
                selected: controls.selected?(item) ?? false,
                onToggle: { controls.onToggle?(item) },
                onSelect: { controls.onSelect?(item) },
                onOpen: { controls.onAction?(item) },
                onToggleExpanded: { surface.setExpanded(item.id) }
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(item.items.filter { $0.entryId != nil }) { TextBlock(content: $0.name) }

                    HStack(spacing: 8) {
                        ForEach(item.items.filter { $0.entryId == nil }) { child in
                            if let ref = child.ref {
                                TableLabel(name: child.name, icon: Iconography.icon(for: ref, size: 12))
                                    .padding(.horizontal, 10)
                                    .frame(height: 26)
                                    .surface(Style.Shape.control)
                            }
                        }
                    }
                }
            }
        )

        ViewContainer(item: item, controls: controls, model: surface.model) { controls.wrapLink?(row, item, 0) ?? row }
    }
}
