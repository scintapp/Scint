import AgencyRuntime
import SwiftUI


@Observable final class Content: Panel {
    var model: Model = .space
    var layout: Layout = .grid
    var position: CGFloat = 280
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case sheet, space, workspace }

    func controls(_ agency: AgencyModel) -> Controls {
        switch model {
        case .sheet: .init()
        case .space: agency.session.space == nil ? RootSpaceMap.controls(agency, self) : SpaceMap.controls(agency, self)
        case .workspace: RootSpaceMap.controls(agency, self)
        }
    }

    func parameters(_ agency: AgencyModel) -> Parameters {
        switch model {
        case .sheet: .init()
        case .space:
            switch self.layout {
            case .grid: SpaceMap.parameters(agency, self)
            case .table: SpaceMap.parameters(agency, self)
            default: SpaceMap.parameters(agency, self)
            }
        case .workspace:
            switch self.layout {
            case .grid: RootSpaceMap.parameters(agency, self)
            case .table: RootSpaceMap.parameters(agency, self)
            default: RootSpaceMap.parameters(agency, self)
            }
        }
    }

    func toolbar() -> some ToolbarContent {
        @Bindable var panel = self

        return Group {
            ToolbarItem(placement: .navigation) { NavigationControls() }
            ToolbarSpacer(.flexible, placement: .navigation)
            ToolbarItem(placement: .principal) { ProcessControls() }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { LayoutPicker() }
            ToolbarItem(placement: .accessoryBar(id: "pathfinder")) { Pathfinder() }
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        @Bindable var console = agency.studio.console

        return VerticalSplit($console.presented, position: $console.position) {
            ScrollView {
                Color.clear.frame(height: 90)

                switch model {
                case .sheet:
                    let sheet = Editor.sheet(for: agency.session.workspace)

                    Editor(ref: sheet)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(32)
                default:
                    Builder.build(agency, self)
                }
            }
        } bottom: {
            agency.studio.console.view(agency)
        }
        .environment(agency)
        .ignoresSafeArea(.container, edges: .top)
        .scrollEdgeEffectStyle(.hard, for: .top)
        .toolbar(removing: .title)
        .toolbar { toolbar() }
    }
}
