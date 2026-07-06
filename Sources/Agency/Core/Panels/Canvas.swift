import AgencyRuntime
import SwiftUI


@Observable final class Canvas: Panel {
    var model: Model = .browser
    var layout: Layout = .grid
    var position: CGFloat = 280
    var presented: Bool = true
    var state: Set<AnyHashable> = []
    var leading: CGFloat = 0
    var trailing: CGFloat = 0

    enum Model: CaseIterable { case browser, composer, editor }

    func controls(_ agency: AgencyModel) -> Controls { SpaceMap.controls(agency, self) }
    func parameters(_ agency: AgencyModel) -> PanelParams { SpaceMap.parameters(agency, self) }

    func toolbar() -> some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigation) { NavigationControls() }
            ToolbarItem(placement: .principal) { ProcessControls() }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { CanvasControls() }
            ToolbarItem(placement: .accessoryBar(id: "pathfinder")) { PathControls() }
        }
    }

    func view(_ agency: AgencyModel, _ content: some View) -> some View {
        @Bindable var utility = agency.studio.utility
        return VerticalSplit($utility.presented, position: $utility.position) {
            content
        } bottom: {
            agency.studio.utility.view(agency)
        }
        .toolbar { toolbar() }
    }

    func view(_ agency: AgencyModel) -> some View {
        @Bindable var trailing = agency.studio.editor
        return HorizontalSplit($trailing.presented, $trailing.position, .init(visibleInsets: NSEdgeInsets(top: 86, left: 0, bottom: 0, right: 0))) {
            if agency.session.selected.space != nil { agency.studio.browser.view(agency) }
            else { agency.studio.dashboard.view(agency) }
        } trailing: {
            agency.studio.editor.view(agency)
        }
    }
}
