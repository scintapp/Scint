import SwiftUI


struct PanelSurface<P: Panel>: Surface {
    var host: any Host
    let panel: P
    let model: any Model

    init(panel: P, model: any Model) {
        self.host = panel
        self.panel = panel
        self.model = model
    }

    var body: some View {
        let params = panel.parameters(model)

        if let panelParams = params.panel {
            Factory.build(panel, panelParams, panel.controls(model))
        }
    }
}
