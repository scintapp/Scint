import SwiftUI
import ScintRuntime
import ScintComponents


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

        ViewChrome(item: item, controls: controls, model: surface.model) {
            if item.trailingKind == .button { Button { controls.onAction?(item) } label: { row }.buttonStyle(.plain) }
            else if item.trailingKind == nil, item.ref != nil || item.entryId != nil { Button { controls.onSelect?(item) } label: { row }.buttonStyle(.plain) }
            else { row }
        }
    }
}
