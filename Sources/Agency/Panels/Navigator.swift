import AgencyRuntime
import SwiftUI


enum NavigatorModel: CaseIterable {
    case workspace, transcripts, library

    var label: String {
        switch self {
            case .workspace: "Workspace"
            case .transcripts: "Transcripts"
            case .library: "Library"
        }
    }

    var image: String {
        switch self {
            case .workspace: "cube.transparent"
            case .transcripts: "bubble.left.and.text.bubble.right"
            case .library: "books.vertical"
        }
    }
}

@Observable final class Navigator: Panel {
    var model: NavigatorModel = .workspace
    var presented: Bool = true
    var position: CGFloat = 0
    var state: StateContainer = .init()
    

    func controls(_ model: any Model) -> Controls {
        switch self.model {
            case .workspace: return WorkspaceNavigator.controls(model)
            case .library: return LibraryNavigator.controls(model)
            case .transcripts: return TranscriptsNavigator.controls(model)
        }
     }
    func parameters(_ model: any Model) -> Params {
        switch self.model {
            case .workspace: return WorkspaceNavigator.parameters(model)
            case .library: return LibraryNavigator.parameters(model)
            case .transcripts: return TranscriptsNavigator.parameters(model)
        }
    }

    func surface(_ model: any Model) -> some View {
        let surface = AnySurface(panel: self, model: model)

        return surface.render(surface, parameters(model), controls(model))
            .scrollEdgeEffectStyle(.soft, for: .top)
            .safeAreaBar(edge: .top) { NavigatorTabs(navigator: self) }
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { NavigatorToggle(navigator: self) }
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
    }
}


