import SwiftUI
import ScintRuntime
import ScintComponents


@MainActor struct RowFactory {
    @ViewBuilder static func build(_ surface: some Surface, _ section: SectionParams, _ controls: Controls) -> some View {
        let state = surface.host.state
        let key: [AnyHashable] = ["row", section.id]
        let current = section.sections.first { $0.id == state[key, as: AnyHashable.self] } ?? section.sections.first

        RowLayout {
            ForEach(Array(section.sections.enumerated()), id: \.element.id) { index, peer in
                RowCell(
                    primary: peer.name,
                    secondary: peer.description,
                    marker: peer.image,
                    tint: peer.tint ?? Style.Tint.accent.bright,
                    selected: peer.id == current?.id,
                    divided: index > 0 && peer.id != current?.id && section.sections[index - 1].id != current?.id,
                    onSelect: { state[key, as: AnyHashable.self] = peer.id }
                )
            }
        }

        if let current {
            switch current.layout {
                case .table: TableFactory.build(surface, current, controls)
                default: EmptyView()
            }
        }
    }
}
