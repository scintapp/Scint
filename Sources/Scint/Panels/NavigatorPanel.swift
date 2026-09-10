import SwiftUI


@Observable final class NavigatorPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init(presented: true)
    var surface: PanelSurface = .spaces

    enum PanelSurface: String, CaseIterable {
        case spaces
        var label: String { rawValue.capitalized }
        var image: String { "cube.transparent" }
    }

    func controls(_ model: any Model) -> Controls {
        AssistantSidebar.controls(model)
    }

    func parameters(_ model: any Model) -> Params {
        AssistantSidebar.parameters(model)
    }

    func surface(_ model: any Model) -> some View {
        AnySurface(panel: self, model: model)
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { NavigatorToggle(presented: bindable.presented) }
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
