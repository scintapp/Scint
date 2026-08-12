import SwiftUI


@Observable final class InspectorPanel: Panel {
    var state: PanelState = .init()
    var surface: InspectorSurface = .workspace
    enum InspectorSurface: String, CaseIterable { case material, space, workspace }
    func controls(_ model: any Model) -> Controls { SpaceGroup.controls(model) }
    func parameters(_ model: any Model) -> Params { SpaceGroup.parameters(model) }

    func surface(_ model: any Model) -> some View {
        AnySurface(panel: self, model: model)
            .scrollEdgeEffectStyle(.hard, for: .top)
            .toolbar {
                @Bindable var state = self.state
                ToolbarSpacer(.flexible, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { InspectorToggle(presented: $state.presented) }
            }
    }
}

