import SwiftUI


@Observable final class NavigatorPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init(presented: true)
    var surface: PanelSurface = .spaces

    enum PanelSurface: String, CaseIterable {
        case spaces, activity

        var label: String { rawValue.capitalized }

        var image: String {
            switch self {
                case .spaces: "cube.transparent"
                case .activity: "bell"
            }
        }
    }

    func controls(_ model: any Model) -> Controls {
        switch surface {
            case .spaces: WorkspaceNavigator.controls(model)
            case .activity: WorkspaceNavigator.controls(model)
        }
    }

    func parameters(_ model: any Model) -> Params {
        switch surface {
            case .spaces: WorkspaceNavigator.parameters(model)
            case .activity: WorkspaceNavigator.parameters(model)
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
