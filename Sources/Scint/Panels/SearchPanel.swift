import Foundation
import SwiftUI


@Observable final class SearchPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init()
    var surface: PanelSurface {
        get { PanelSurface(rawValue: state.surface) ?? .everything }
        set { state.surface = newValue.rawValue }
    }

    enum PanelSurface: String, CaseIterable {
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

    func controls(_ model: any Model) -> Controls { surface.query.controls(model) }

    func parameters(_ model: any Model) -> Params {
        let content = surface.query.parameters(model)
        let surfaces = PanelSurface.allCases.map { ItemParams(key: $0.rawValue, name: $0.label, image: $0.image) }

        return .init(
            id: PanelKey.search.id,
            layout: content.layout,
            nesting: content.nesting,
            header: content.header,
            panel: .init(
                key: .search,
                sizing: .init(size: .init(width: 640, height: 480)),
                input: .init(key: "query", name: surface.placeholder, image: surface.image),
                items: surfaces,
                selection: surfaces.first { $0.key == surface.rawValue },
                dismissal: [.escape, .outsideClick],
                movable: true,
                resizable: false,
                pinnable: false
            ),
            sections: content.sections
        )
    }

    func surface(_ model: any Model) -> some View { AnySurface(panel: self, model: model) }
}
