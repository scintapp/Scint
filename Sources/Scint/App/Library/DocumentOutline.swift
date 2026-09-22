import Foundation
import SwiftUI


struct DocumentOutline: Surface {
    var panel: any Panel
    var model: any Model
    var surface: AnySurface { .init(panel: panel, model: model) }

    var body: some View {
        surface.render(surface, panel.parameters(model), panel.controls(model))
            .frame(maxHeight: .infinity)
            .scrollEdgeEffectStyle(.soft, for: .top)
    }
}

