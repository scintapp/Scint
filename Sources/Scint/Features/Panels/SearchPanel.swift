import Foundation
import SwiftUI


@Observable final class SearchPanel: Panel {
    var state: StateContainer = .init()
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

    func controls(_ model: any Model) -> Controls { PanelQuery.controls(model) }
    func parameters(_ model: any Model) -> Params { PanelQuery.parameters(model) }
    func surface(_ model: any Model) -> some View { SearchSurface(panel: self, model: model) }
}
