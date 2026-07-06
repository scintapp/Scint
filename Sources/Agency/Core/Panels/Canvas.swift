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

    func controls(_ agency: AgencyModel) -> Controls {
        SpaceMap.controls(agency, self)
    }

    func parameters(_ agency: AgencyModel) -> PanelParams {
        SpaceMap.parameters(agency, self)
    }

    func toolbar() -> some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigation) { NavigationControls() }
            ToolbarSpacer(.flexible, placement: .navigation)
            ToolbarItem(placement: .principal) { ProcessControls() }
            ToolbarSpacer(.flexible, placement: .secondaryAction)
            ToolbarItem(placement: .primaryAction) { LayoutPicker() }
            ToolbarItem(placement: .accessoryBar(id: "pathfinder")) { PathControls() }
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        Group {
            @Bindable var browser = agency.studio.browser
            @Bindable var utility = agency.studio.utility

            VerticalSplit($utility.presented, position: $utility.position) {
                HorizontalSplit($browser.presented, position: $browser.position) {
                    agency.studio.browser.view(agency)
                        .safeAreaInset(edge: .top) { Color.clear.frame(height: 80) }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .scrollEdgeEffectStyle(.hard, for: .top)
                } trailing: {
                    agency.studio.editor.view(agency)
                        .safeAreaInset(edge: .top) { Color.clear.frame(height: 80) }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .scrollEdgeEffectStyle(.hard, for: .top)
                }
            } bottom: {
                agency.studio.utility.view(agency)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .toolbar(removing: .title)
            .toolbar { toolbar() }
        }
    }
}
