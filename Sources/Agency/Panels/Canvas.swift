import AgencyRuntime
import SwiftUI


@Observable final class Canvas: Panel {
    var model: Model = .composer
    var position: CGFloat = 280
    var presented: Bool = false
    var state = SurfaceState()

    enum Model: CaseIterable { case browser, composer, editor }

    func toolbar() -> some ToolbarContent {
        return Group {
            ToolbarItem(placement: .navigation) { NavigationControls() }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .principal) { ContextControls() }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { CanvasControls() }
        }
    }

    func leading(_ agency: AgencyModel) -> some View {
        ScrollView {
            if agency.session.selected.space != nil { agency.studio.features.browser }
            else { agency.studio.features.dashboard }
        }
        .scrollEdgeEffectStyle(.hard, for: .top)
        .safeAreaBar(edge: .top, alignment: .leading) { PathControls() }
    }

    func trailing(_ agency: AgencyModel) -> some View {
        ScrollView {
            switch model {
                case .editor: agency.studio.features.editor
                default: agency.studio.features.composer
            }
        }
        .scrollEdgeEffectStyle(.hard, for: .top)
        .safeAreaBar(edge: .top, alignment: .leading) { ActiveCanvasControls() }
    }

    func view(_ agency: AgencyModel) -> some View {
        @Bindable var canvas = self
        return HorizontalSplit($canvas.presented, $canvas.position) {
            leading(agency)
        } trailing: {
            trailing(agency)
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar { toolbar () }
    }
}
