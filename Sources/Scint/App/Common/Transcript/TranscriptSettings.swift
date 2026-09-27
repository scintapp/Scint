import Foundation
import SwiftUI


struct TranscriptSettings: Surface {
    var panel: any Panel
    var model: any Model
    var surface: AnySurface { .init(panel: panel, model: model) }

    var body: some View {
        surface.render(
            surface,
            SpaceSettingsQuery.parameters(model),
            SpaceSettingsQuery.controls(model))
        .frame(maxHeight: .infinity)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
