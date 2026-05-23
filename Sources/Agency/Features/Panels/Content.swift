
import AgencyRuntime
import SwiftUI


struct ContentToolbar: ToolbarContent {
    @Environment(AgencyModel.self) var agency
    @Binding var presented: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) { NavigationControls() }
        ToolbarItem(placement: .principal) { RuntimeControls() }
        ToolbarItem(placement: .primaryAction) { LayoutPicker() }
        ToolbarItem(placement: .primaryAction) { OutlineToggle() }
        ToolbarItem(placement: .accessoryBar(id: "pathfinder")) { Pathfinder() }
    }
}

@Observable final class Content: Panel {
    var model: Model = .space
    var position: CGFloat = 280
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable {
        case workspace, space, sheet

        var image: String {
            switch self {
            case .workspace: "cube.transparent"
            case .space: "app"
            case .sheet: "square.and.pencil"
            }
        }
    }

    func closures(_ agency: AgencyModel) -> Closures {
        switch self.model {
        case .workspace: SpaceMapper.closures(agency, self)
        case .space: SpaceMapper.closures(agency, self)
        case .sheet: .init()
        }
    }

    func params(_ agency: AgencyModel) -> Params {
        switch self.model {
        case .workspace: SpaceMapper.params(agency, self)
        case .space: SpaceMapper.params(agency, self)
        case .sheet: .init()
        }
    }

    @MainActor func build(_ agency: AgencyModel) -> some View {
        @Bindable var content = self

        return ScrollView {
            Color.clear.frame(height: 90)
            switch content.model {
            case .workspace:
                Builder.build(self, closures(agency), params(agency))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 12)

            case .space:
                Builder.build(self, closures(agency), params(agency))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 12)

            case .sheet:
                if let _ = agency.session.sheet {
                    Editor(ref: agency.session.sheet!)
                        .frame(maxWidth: 700, maxHeight: .infinity,  alignment: .top)
                        .padding(.horizontal, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Design.Background.content)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}





