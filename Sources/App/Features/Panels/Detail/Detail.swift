import AgencyRuntime
import SwiftUI


@Observable final class Detail: Panel {
    var model: Model = .browser
    var layout: Layout = .grid
    var position: CGFloat = 280
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case browser, editor }

    func controls(_ agency: AgencyModel) -> Controls {
        switch model {
            case .browser: SpaceMap.controls(agency, self)
            case .editor: .init()
        }
    }

    func parameters(_ agency: AgencyModel) -> PanelParams {
        switch model {
            case .browser: SpaceMap.parameters(agency, self)
            case .editor: .init()
        }
    }

    func toolbar() -> some ToolbarContent {
        return Group {
            ToolbarItem(placement: .navigation) { NavigationControls() }
            ToolbarItem(placement: .principal) { ProcessControls() }
            ToolbarItem(placement: .primaryAction) { EmptyView() }
            ToolbarItem(placement: .accessoryBar(id: "pathfinder")) { PathControls() }
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        @Bindable var console = agency.studio.console
        return ZStack(alignment: .top) {
            VerticalSplit($console.presented, position: $console.position) {
                ScrollView {
                    switch model {
                        case .browser: agency.studio.browser.view(agency)
                        case .editor: agency.studio.editor.view(agency)
                    }
                }
                .safeAreaInset(edge: .top) { Color.clear.frame(height: 80) }
                .scrollEdgeEffectStyle(.hard, for: .top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } bottom: {
                agency.studio.console.view(agency)
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .toolbar(removing: .title)
        .toolbar { toolbar() }
    }
}
