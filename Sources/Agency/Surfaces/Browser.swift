import AgencyRuntime
import SwiftUI


@Observable final class Browser: Surface {
    var model: Model = .single
    var layout: Layout = .grid
    var position: CGFloat = 280
    var presented: Bool = true
    var state: Set<AnyHashable> = []

    enum Model: CaseIterable { case single }

    func controls(_ agency: AgencyModel) -> Controls { SpaceMap.controls(agency, self) }
    func parameters(_ agency: AgencyModel) -> PanelParams { SpaceMap.parameters(agency, self) }
    func view(_ agency: AgencyModel) -> some View { Builder.build(agency, self) }
}

@Observable final class Dashboard: Panel {
    var model: Model = .single
    var layout: Layout = .grid
    var position: CGFloat = 280
    var presented: Bool = true
    var state: Set<AnyHashable> = []

    enum Model: CaseIterable { case single }

    func controls(_ agency: AgencyModel) -> Controls { DashboardMap.controls(agency, self) }
    func parameters(_ agency: AgencyModel) -> PanelParams { DashboardMap.parameters(agency, self) }
    func view(_ agency: AgencyModel) -> some View { WorkspaceLayout() }
}
