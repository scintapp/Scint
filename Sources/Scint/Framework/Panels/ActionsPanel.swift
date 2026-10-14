import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


@Observable final class ActionsPanel: Panel {
    var state: StateContainer = .init()
    var surface: PanelSurface = .actions

    enum PanelSurface: String, CaseIterable { case actions }

    func controls(_ model: any Model) -> Controls {
        var controls = ActionsList.controls(model)
        let run = controls.onSelect
        let change = controls.onValueChange
        let select = { (item: ItemParams) in
            (model as? PanelModel)?.dismiss(self)
            run?(item)
        }

        controls.onValueChange = { item, query in
            guard item.key == "query" else { change?(item, query); return }
            guard query != self.state.query else { return }
            self.state.query = query
            self.state.index = 0
        }
        controls.onSelect = select
        controls.onInput = { input in
            PanelNavigation.handle(input, rows: { self.parameters(model).rows(self.state.surface) }, index: self.bindable.index, onSelect: select, onSecondary: nil, onCancel: nil)
        }
        return controls
    }

    func parameters(_ model: any Model) -> Params {
        var params = ActionsList.parameters(model)
        let results = ActionsList.controls(model).results

        params.sections = params.sections.flatMap { results?($0, state.query) ?? [$0] }
        params.input?.value = state.query
        params.cursor = PanelNavigation.current(params.rows(state.surface), at: state.index)?.id
        params.panel = PanelParams(size: CGSize(width: 640, height: 480))
        return params
    }

    func surface(_ model: PanelModel) -> some View { AnySurface(host: self, model: model) }
}
