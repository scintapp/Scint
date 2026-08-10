import Foundation
import SwiftUI


@Observable final class SearchPanel: Panel {
    var key: AppKey = .studio
    var state: AppState = .init()
    var mode: Mode = .everything

    enum Mode: String, CaseIterable {
        case everything, content, interfaces, workspace

        var label: String { self.rawValue.capitalized }
        var placeholder: String { label }

        var image: String {
            switch self {
                case .everything: "magnifyingglass"
                case .content: "command"
                case .interfaces: "switch.2"
                case .workspace: "cube.transparent"
            }
        }
    }

    func parameters(_ model: any Model) -> Params {
        switch mode {
            case .everything: EverythingQuery.parameters(model)
            case .content: ContentQuery.parameters(model)
            case .interfaces: InterfacesQuery.parameters(model)
            case .workspace: WorkspaceQuery.parameters(model)
        }
    }

    func controls(_ model: any Model) -> Controls { PanelQuery.controls(model) }
    func parameters(_ model: any Model) -> Params { PanelQuery.parameters(model) }
    func surface(_ model: any Model) -> some View { SearchSurface(host: self, model: model) }
}
