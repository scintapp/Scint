import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


final class SearchPanel: Panel {
    var state: PanelState = .init()

    var surface: PanelSurface {
        get { PanelSurface(rawValue: state.surface) ?? .everything }
        set { state.surface = newValue.rawValue }
    }

    enum PanelSurface: String, CaseIterable {
        case everything, content, interfaces, projects

        var label: String { self.rawValue.capitalized }
        var placeholder: String { label }
        var limit: Int { self == .everything ? 50 / 3 : 50 }

        var image: String {
            switch self {
                case .everything: "magnifyingglass"
                case .content: "command"
                case .interfaces: "switch.2"
                case .projects: "cube.transparent"
            }
        }

        var groups: [(name: String, filter: String)] {
            switch self {
                case .everything: [("Content", "document"), ("Interfaces", "interface"), ("Workspace", "structure")]
                case .content: [("", "document")]
                case .interfaces: [("Artifacts", "artifact"), ("Commands", "command"), ("Harnesses", "harness")]
                case .projects: [("", "structure")]
            }
        }
    }

    func parameters(_ model: Model) -> Params {
        .init(
            id: PanelKey.search.id,
            panel: .init(
                key: .search,
                sizing: .init(size: .init(width: 640, height: 480)),
                dismissal: [.escape, .outsideClick],
                movable: true,
                resizable: false,
                pinnable: false
            )
        )
    }

    func surface(_ model: any Model) -> some View {
        SearchContent(panel: self, model: model) }
}
