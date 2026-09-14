import SwiftUI
import Foundation


struct HarnessSurface: Surface {
    var panel: any Panel
    var model: any Model
    var surface: AnySurface { .init(panel: panel, model: model) }

    var body: some View {
        surface.render(surface, SpaceSettings.parameters(model), SpaceSettings.controls(model))
            .frame(maxHeight: .infinity)
            .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
