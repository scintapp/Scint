import SwiftUI


@Observable final class NavigatorPanel: Panel {
    var state: PanelState = .init(presented: true)
    var surface: NavigatorSurface = .workspace

    enum NavigatorSurface: String, CaseIterable {
        case workspace

        var label: String { rawValue.capitalized }
        var image: String { "cube.transparent" }
    }

    func controls(_ model: any Model) -> Controls {
        WorkspaceNavigator.controls(model)
    }

    func parameters(_ model: any Model) -> Params {
        WorkspaceNavigator.parameters(model)
    }

    func surface(_ model: any Model) -> some View {
        AnySurface(panel: self, model: model)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .safeAreaBar(edge: .top) { Filter(text: state.bindable.filter) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) { NavigatorToggle(presented: state.bindable.presented) }
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
    }
}
