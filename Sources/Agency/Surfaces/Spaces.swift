import AgencyRuntime
import SwiftUI


@Observable final class Browser: Panel {
    var model: Model = .workspace
    var layout: Layout = .grid
    var position: CGFloat = 280
    var presented: Bool = true
    var state: Set<AnyHashable> = []

    enum Model: CaseIterable { case space, workspace }

    func controls(_ agency: AgencyModel) -> Controls {
        switch model {
            case .space: return SpaceMap.controls(agency, self)
            case .workspace: return WorkspaceMap.controls(agency, self)
        }
    }

    func parameters(_ agency: AgencyModel) -> PanelParams {
        switch model {
            case .space: return SpaceMap.parameters(agency, self)
            case .workspace: return WorkspaceMap.parameters(agency, self)
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        ZStack(alignment: .top) {
            switch model {
                case .space: Builder.build(agency, self)
                case .workspace: WorkspaceLayout()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture { agency.focus(agency.session.selected.structure ?? agency.session.workspace) }
        .contentShape(Rectangle())
    }
}
