import SwiftUI


@Observable final class NavigatorPanel: Panel {
    var state: PanelState = .init(presented: true)
    var surface: PanelSurface = .workspace

    enum PanelSurface: String, CaseIterable {
        case workspace, activity, library

        var label: String { rawValue.capitalized }

        var image: String {
            switch self {
                case .workspace: "cube.transparent"
                case .activity: "bell"
                case .library: "building.classical.columns"
            }
        }
    }

    func controls(_ model: any Model) -> Controls {
        switch surface {
            case .workspace: WorkspaceNavigator.controls(model)
            case .activity: TranscriptsList.controls(model)
            case .library: LibraryNavigator.controls(model)
        }
    }

    func parameters(_ model: any Model) -> Params {
        switch surface {
            case .workspace: WorkspaceNavigator.parameters(model)
            case .activity: TranscriptsList.parameters(model)
            case .library: LibraryNavigator.parameters(model)
        }
    }

    func surface(_ model: any Model) -> some View {
        AnySurface(panel: self, model: model)
            .safeAreaBar(edge: .top) { NavigatorTabs(panel: self) }
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { NavigatorToggle(presented: state.bindable.presented) }
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
    }
}
