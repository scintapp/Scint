import SwiftUI
import ScintRuntime
import ScintComponents


@MainActor struct PanelFactory {
    @ViewBuilder static func build(_ surface: some Surface, _ section: SectionParams, _ controls: Controls) -> some View {
        if section.header, !section.name.isEmpty { PanelHeader(name: section.name) }

        ForEach(section.items) { item in
            if item.isParent {
                if !item.name.isEmpty { PanelHeader(name: item.name) }
                ForEach(item.items) { build(surface, $0, controls) }
            } else {
                build(surface, item, controls)
            }
        }
    }

    @ViewBuilder static func build(_ surface: some Surface, _ item: ItemParams, _ controls: Controls) -> some View {
        if item.trailingKind == .field {
            PanelField(text: .init(get: { item.value ?? "" }, set: { controls.onValueChange?(item, $0) }), field: item, onInput: controls.onInput)
        } else {
            PanelRow(item: item, active: controls.focused?(item) ?? false, selected: controls.selected?(item) ?? false) { controls.onSelect?(item) }
                .id(item.id)
        }
    }
}
