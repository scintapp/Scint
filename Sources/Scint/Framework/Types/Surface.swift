import SwiftUI


@MainActor protocol Surface: View {
    var host: any Host { get set }
    var model: any Model { get set }
    func isExpanded(_ id: AnyHashable) -> Bool
    func setExpanded(_ id: AnyHashable)
}

extension Surface {
    var render: (Self, Params, Controls) -> any View { Factory.build(_ :_ :_ :) }
    func isExpanded(_ id: AnyHashable) -> Bool { host.state.isExpanded(id) }
    func setExpanded(_ id: AnyHashable) { host.state.setExpanded(id) }
}

struct AnySurface: Surface {
    var host: any Host
    var model: any Model
    var body: some View { render(self, host.parameters(model), host.controls(model)) }
    var render: (Self, Params, Controls) -> some View { Factory.build(_ :_ :_ :) }
    func isExpanded(_ id: AnyHashable) -> Bool { host.state.isExpanded(id) }
    func setExpanded(_ id: AnyHashable) { host.state.setExpanded(id) }
}
