import SwiftUI


@Observable final class NavigatorPanel: Panel {
    var state: PanelState = .init(presented: true)
    func controls(_ model: any Model) -> Controls { SidebarMapper.controls(model) }
    func parameters(_ model: any Model) -> Params { SidebarMapper.parameters(model) }

    func surface(_ model: any Model) -> some View {
        AnySurface(host: self, model: model)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    @Bindable var state = self.state
                    SidebarToggle(presented: $state.presented)
                }
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
    }
}
