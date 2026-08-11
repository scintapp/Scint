import SwiftUI


private let anyRef = Reference(Workspace.self)

class AnyModel: Model {
    var frame: any Panel
    var session: Session

    init(_ workspace: Reference) {
        self.frame = AnyPanel()
        self.session = .init(anyRef)
    }
}

class AnyPanel: Panel {
    var state: PanelState
    init(state: PanelState = .init()) { self.state = state }
    func controls(_ model: any Model) -> Controls { .init() }
    func parameters(_ model: any Model) -> Params { .init() }
    func surface(_ model: any Model) -> some View { EmptyView() }
}

struct AnySurface: Surface {
    var host: any Host
    let model: any Model
    var body: some View { render(self, host.parameters(model), host.controls(model)) }
    var render: (Self, Params, Controls) -> some View { Factory.build(_ :_ :_ :) }
    func isExpanded(_ id: AnyHashable) -> Bool { host.state.isExpanded(id) }
    func setExpanded(_ id: AnyHashable) { host.state.setExpanded(id) }
}

