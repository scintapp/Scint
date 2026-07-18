import AgencyRuntime
import SwiftUI


@Observable final class Navigator: Panel {
    var model: Model = .workspace
    var presented: Bool = true
    var position: CGFloat = 0
    var state: StateContainer = .init()

    enum Model: CaseIterable {
        case workspace, transcripts, directories, library

        var label: String {
            switch self {
                case .workspace: "Workspace"
                case .transcripts: "Transcripts"
                case .directories: "Files"
                case .library: "Library"
            }
        }

        var image: String {
            switch self {
                case .workspace: "cube.transparent"
                case .directories: "folder"
                case .transcripts: "bubble.left.and.text.bubble.right"
                case .library: "books.vertical"
            }
        }
    }

    func controls(_ agency: AgencyModel) -> Controls { NavigatorMaps.controls(agency) }
    func parameters(_ agency: AgencyModel) -> Params { NavigatorMaps.parameters(agency) }

    func surface(_ agency: AgencyModel) -> some View {
        let surface = AnySurface(panel: self)

        return surface.view(surface, parameters(agency), controls(agency))
            .environment(agency)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .safeAreaBar(edge: .top) { NavigatorTabs() }
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { NavigatorToggle() }
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
    }
}
