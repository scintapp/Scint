import AgencyRuntime
import SwiftUI


@Observable final class Content: Panel {
    var model: Model = .browser
    var layout: Layout = .grid
    var position: CGFloat = 280
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case browser, composer, writer }

    func controls(_ agency: AgencyModel) -> Controls {
        switch model {
            case .browser: return SpaceMap.controls(agency, self)
            case .composer: return ComposerMap.controls(agency, self)
            case .writer: return .init()
        }
    }

    func parameters(_ agency: AgencyModel) -> Parameters {
        switch model {
            case .browser: return SpaceMap.parameters(agency, self)
            case .composer: return ComposerMap.parameters(agency, self)
            case .writer: return .init()
        }
    }

    func toolbar() -> some ToolbarContent {
        return Group {
            ToolbarItem(placement: .navigation) { NavigationControls() }
            ToolbarSpacer(.flexible, placement: .navigation)
            ToolbarItem(placement: .principal) { FocusControls() }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { ModalityPicker() }
            ToolbarItem(placement: .accessoryBar(id: "pathfinder")) { Pathfinder() }
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        @Bindable var console = agency.studio.console

        return VerticalSplit($console.presented, position: $console.position) {
            switch model {
                case .browser: agency.studio.browser.view(agency)
                case .composer: agency.studio.composer.view(agency)
                case .writer: agency.studio.writer.view(agency)
            }
        } bottom: {
            agency.studio.console.view(agency)
        }
        .environment(agency)
        .ignoresSafeArea(.all, edges: .top)
        .toolbar(removing: .title)
        .toolbar { toolbar() }
    }
}
