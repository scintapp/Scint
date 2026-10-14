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
        let select = { (item: ItemParams) in
            (model as? PanelModel)?.dismiss(self)
            self.onPick(item)
        }

        return .init(
            onValueChange: { item, query in
                guard item.key == "query", query != self.state.query else { return }
                self.state.query = query
                self.state.index = 0
            },
            selected: { chosen.contains($0.id) },
            onSelect: select,
            onInput: { input in
                PanelNavigation.handle(input, rows: { self.parameters(model).rows(self.state.surface) }, index: self.bindable.index, onSelect: select, onSecondary: nil, onCancel: nil)
            }
        )
    }

    func parameters(_ model: any Model) -> Params {
        var params = Params(
            description: "No matches",
            input: ItemParams(key: "query", name: "Filter", image: "magnifyingglass", trailingKind: .field, value: state.query),
            panel: PanelParams(
                size: CGSize(width: 280, height: min(max(CGFloat(items.count) * 36 + 52, 132), 360)),
                placement: .anchored(anchor),
                dismissal: [.escape, .outsideClick, .resignKey]
            ),
            sections: [.init(id: "choices", header: false, layout: .list, items: PanelList.narrowed(items, by: state.query))]
        )
        params.cursor = PanelNavigation.current(params.rows(state.surface), at: state.index)?.id
        return params
    }

    func surface(_ model: PanelModel) -> some View { AnySurface(host: self, model: model) }
}
