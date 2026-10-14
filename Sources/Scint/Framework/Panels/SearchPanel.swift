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
        var controls = switch surface {
            case .results: SearchList.controls(model)
            case .detail: ReferenceDetail.controls(model)
        }
        
        let select = controls.onSelect
        let change = controls.onValueChange
        let focus = controls.onAction
        let detail: (enter: ((ItemParams) -> Void)?, leave: (() -> Bool)?) = switch surface {
            case .results: ({ focus?($0); self.surface = .detail; self.state.index = 0 }, nil)
            case .detail: (nil, { self.surface = .results; self.state.index = 0; return true })
        }

        controls.onValueChange = { item, query in
            guard item.key == "query" else { change?(item, query); return }
            guard query != self.state.query else { return }
            self.state.query = query
            self.state.index = 0
        }
        controls.onTabSelect = { tab in
            self.state.surface = tab.id.base as? String ?? ""
            self.state.query = ""
            self.state.index = 0
        }
        controls.onInput = { input in
            PanelNavigation.handle(
                input,
                rows: { self.parameters(model).rows(self.state.surface) },
                index: self.bindable.index,
                onSelect: select,
                onSecondary: detail.enter,
                onCancel: detail.leave
            )
        }
        return controls
    }

    func parameters(_ model: any Model) -> Params {
        var params = switch surface {
            case .results: SearchList.parameters(model)
            case .detail: ReferenceDetail.parameters(model)
        }

        if surface == .results, let tab = params.tab(state.surface), let index = params.sections.firstIndex(of: tab) {
            let results = SearchList.controls(model).results
            params.sections[index].sections = tab.sections
                .flatMap { results?($0, state.query) ?? [$0] }
                .filter { !$0.items.isEmpty }
            params.input = ItemParams(key: "query", name: tab.name, image: tab.image, trailingKind: .field, value: state.query)
        }

        params.cursor = PanelNavigation.current(params.rows(state.surface), at: state.index)?.id
        params.panel = PanelParams(size: CGSize(width: 640, height: 480))
        return params
    }

    func surface(_ model: PanelModel) -> some View { AnySurface(host: self, model: model) }
}
