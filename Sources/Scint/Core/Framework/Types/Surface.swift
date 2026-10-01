import SwiftUI


@MainActor protocol Surface: View {
    var panel: any Panel { get set }
    var model: any Model { get set }
    func isExpanded(_ id: AnyHashable) -> Bool
    func setExpanded(_ id: AnyHashable)
}

extension Surface {
    var render: (Self, Params, Controls) -> any View { PanelFactory.build(_ :_ :_ :) }
    func isExpanded(_ id: AnyHashable) -> Bool { panel.state.isExpanded(id) }
    func setExpanded(_ id: AnyHashable) { panel.state.setExpanded(id) }
}

struct AnySurface: Surface {
    var panel: any Panel
    var model: any Model
    var body: some View { render(self, panel.parameters(model), panel.controls(model)) }
    var render: (Self, Params, Controls) -> some View { PanelFactory.build(_ :_ :_ :) }
    func isExpanded(_ id: AnyHashable) -> Bool { panel.state.isExpanded(id) }
    func setExpanded(_ id: AnyHashable) { panel.state.setExpanded(id) }
}
