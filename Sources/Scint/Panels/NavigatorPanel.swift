import SwiftUI


@Observable final class NavigatorPanel: Panel {
    var state: PanelState = .init(presented: true)
    var surface: PanelSurface = .workspace

    enum PanelSurface: String, CaseIterable {
        case workspace, activity

        var label: String { rawValue.capitalized }

        var image: String {
            switch self {
                case .workspace: "cube.transparent"
                case .activity: "bell"
            }
        }
    }

    func controls(_ model: any Model) -> Controls {
        switch surface {
            case .workspace: WorkspaceNavigator.controls(model)
            case .activity: WorkspaceNavigator.controls(model)
        }
    }

    func parameters(_ model: any Model) -> Params {
        switch surface {
            case .workspace: WorkspaceNavigator.parameters(model)
            case .activity: WorkspaceNavigator.parameters(model)
        }
    }

    func surface(_ model: any Model) -> some View {
        Group {
            switch surface {
                case .workspace:
                    AnySurface(panel: self, model: model)
                case .activity:
                    ActivitySurface(panel: self, model: model)
            }
        }
        .safeAreaBar(edge: .top) { NavigatorTabs(panel: self) }
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { NavigatorToggle(presented: state.bindable.presented) }
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
    }
}
