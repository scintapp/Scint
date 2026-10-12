import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


@Observable final class SearchPanel: Panel {
    var state: StateContainer = .init()

    var surface: PanelSurface {
        get { state.detail ? .detail : .results }
        set { state.detail = newValue == .detail }
    }

    enum PanelSurface: String, CaseIterable { case results, detail }

    func controls(_ model: any Model) -> Controls {
        switch surface {
            case .results: SearchList.controls(model)
            case .detail: ReferenceDetail.controls(model)
        }
    }

    func parameters(_ model: any Model) -> Params {
        var params = switch surface {
            case .results: SearchList.parameters(model)
            case .detail: ReferenceDetail.parameters(model)
        }
        params.panel = PanelParams(size: CGSize(width: 640, height: 480))
        return params
    }

    func surface(_ model: PanelModel) -> some View { AnySurface(host: self, model: model) }
}
