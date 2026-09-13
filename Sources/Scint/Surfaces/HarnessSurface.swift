import SwiftUI
import Foundation


struct HarnessSurface: View {
    var ref: Reference? = nil
    var panel: any Panel
    var model: any Model

    var surface: AnySurface { .init(panel: panel, model: model) }

    @State private var presented = false

    var body: some View {
        surface.render(surface, SpaceSettings.parameters(model), SpaceSettings.controls(model))
            .frame(maxWidth: 340, maxHeight: .infinity)
            .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
