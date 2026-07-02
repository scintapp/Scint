import AgencyRuntime
import SwiftUI


@Observable final class DetailBrowser: Panel {
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

    func parameters(_ agency: AgencyModel) -> PanelParams {
        switch model {
            case .space: return SpaceMap.parameters(agency, self)
            case .workspace: return WorkspaceMap.parameters(agency, self)
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        ZStack(alignment: .top) {
            VStack(alignment: .center) {
                ScrollView {
                    Builder.build(agency, self)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .background {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { agency.focus(agency.session.selected.structure) }
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}
