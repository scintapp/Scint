import AgencyRuntime
import SwiftUI


@Observable final class Browser: Panel {
    var model: Model = .space
    var layout: Layout = .grid
    var position: CGFloat = 280
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case space, workspace }

    func controls(_ agency: AgencyModel) -> Controls {
        switch model {
            case .space: return SpaceMap.controls(agency, self)
            case .workspace: return WorkspaceMap.controls(agency, self)
        }
    }

    func parameters(_ agency: AgencyModel) -> Parameters {
        switch model {
            case .space: return SpaceMap.parameters(agency, self)
            case .workspace: return WorkspaceMap.parameters(agency, self)
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        ScrollView {
            Color.clear.frame(height: 90)
            Builder.build(agency, self)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { agency.clearFocus() }
        }
        .ignoresSafeArea(.container, edges: .top)
        .scrollEdgeEffectStyle(.hard, for: .top)
    }
}
