import Foundation
import SwiftUI


struct SpaceOutline: Surface {
    var panel: any Panel
    var model: any Model
    var surface: AnySurface { .init(panel: panel, model: model) }

    var body: some View {
        surface.render(surface, SpaceOutlineQuery.parameters(model), SpaceOutlineQuery.controls(model))
            .frame(maxHeight: .infinity)
            .scrollEdgeEffectStyle(.soft, for: .top)
    }
}

