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
        controls.onSelect = { item in
            (model as? PanelModel)?.dismiss(self)
            run?(item)
        }
        return controls
    }

    func parameters(_ model: any Model) -> Params {
        var params = ActionsList.parameters(model)
        params.panel = PanelParams(size: CGSize(width: 640, height: 480))
        return params
    }

    func surface(_ model: PanelModel) -> some View { AnySurface(host: self, model: model) }
}
