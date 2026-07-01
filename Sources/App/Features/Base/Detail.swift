import AgencyRuntime
import SwiftUI


@Observable final class Detail: Panel {
    var model: Model = .browser
    var layout: Layout = .grid
    var position: CGFloat = 280
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case browser, editor, composer }

    func controls(_ agency: AgencyModel) -> Controls {
        switch model {
            case .browser: return SpaceMap.controls(agency, self)
            case .editor: return .init()
            case .composer: return ComposerMap.controls(agency, self)
        }
    }

    func parameters(_ agency: AgencyModel) -> Parameters {
        switch model {
            case .browser: return SpaceMap.parameters(agency, self)
            case .editor: return .init()
            case .composer: return ComposerMap.parameters(agency, self)
        }
    }

    func toolbar() -> some ToolbarContent {
        return Group {
            ToolbarItem(placement: .navigation) { NavigationControls() }
            ToolbarItem(placement: .principal) { ProcessControls() }
            ToolbarItem(placement: .primaryAction) { ModalityControls() }
            ToolbarItem(placement: .accessoryBar(id: "pathfinder")) { PathControls() }
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        @Bindable var console = agency.studio.console
        return ZStack(alignment: .top) {
            VerticalSplit($console.presented, position: $console.position) {
                ScrollView {
                    Color.clear.frame(height: 50)
                    switch model {
                        case .browser: agency.studio.browser.view(agency)
                        case .composer: agency.studio.composer.view(agency)
                        case .editor: agency.studio.editor.view(agency)
                    }
                }
            } bottom: {
                agency.studio.console.view(agency)
            }
            .ignoresSafeArea(.container, edges: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(removing: .title)
        .toolbar { toolbar() }
    }
}
