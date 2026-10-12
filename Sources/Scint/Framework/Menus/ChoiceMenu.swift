import OSLog
import SwiftUI
import ScintRuntime
import ScintComponents


@Observable final class ChoiceMenu: Menu {
    var state: StateContainer = .init()
    var items: [ItemParams] = []
    var anchor: CGRect = .zero
    var onPick: (ItemParams) -> Void = { _ in }

    func controls(_ model: any Model) -> Controls {
        let chosen = Set(items.filter(\.active).map(\.id))
        return .init(
            selected: { chosen.contains($0.id) },
            onSelect: { item in
                (model as? PanelModel)?.dismiss(self)
                self.onPick(item)
            },
            results: { _, query in PanelList.narrowed(self.items, by: query) }
        )
    }

    func parameters(_ model: any Model) -> Params {
        .init(
            description: "No matches",
            panel: PanelParams(
                size: CGSize(width: 280, height: min(max(CGFloat(items.count) * 36 + 52, 132), 360)),
                placement: .anchored(anchor),
                dismissal: [.escape, .outsideClick, .resignKey]
            ),
            sections: [.init(id: "choices", header: false, layout: .list, items: [ItemParams(key: "query", name: "Filter", image: "magnifyingglass", trailingKind: .field)])]
        )
    }

    func surface(_ model: PanelModel) -> some View { AnySurface(host: self, model: model) }
}
