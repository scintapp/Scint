import Foundation
import SwiftUI


@Observable final class SearchPanel: Panel {
    var state: PanelState = .init()

    var mode: Mode {
        get { Mode(rawValue: state.mode) ?? .everything }
        set { state.mode = newValue.rawValue }
    }

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

        var query: any Mapper.Type {
            switch self {
                case .everything: EverythingQuery.self
                case .content: ContentQuery.self
                case .interfaces: InterfacesQuery.self
                case .workspace: WorkspaceQuery.self
            }
        }
    }

    func parameters(_ model: any Model) -> Params {
        let content = mode.query.parameters(model)
        let modes = Mode.allCases.map { ItemParams(key: $0.rawValue, name: $0.label, image: $0.image) }

        return .init(
            id: PanelKey.search.id,
            layout: content.layout,
            nesting: content.nesting,
            header: content.header,
            panel: .init(
                key: .search,
                sizing: .init(size: .init(width: 640, height: 480)),
                input: .init(key: "query", name: mode.placeholder, image: mode.image),
                items: modes,
                selection: modes.first { $0.key == mode.rawValue },
                dismissal: [.escape, .outsideClick],
                movable: true,
                resizable: false,
                pinnable: false
            ),
            components: content.components
        )
    }

    func controls(_ model: any Model) -> Controls { mode.query.controls(model) }

    func surface(_ model: any Model) -> some View { AnySurface(panel: self, model: model) }
}
