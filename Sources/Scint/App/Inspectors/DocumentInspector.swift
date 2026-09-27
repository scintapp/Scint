import Foundation
import SwiftUI


struct DocumentInspector: Surface {
    var panel: any Panel
    var model: any Model
    var inspector: Inspector = .outline

    enum Inspector: CaseIterable { case outline, settings }

    var body: some View {
        let surface = AnySurface(panel: panel, model: model)

        Group {
            switch inspector {
                case .outline:
                    return surface.render(
                        surface,
                        DocumentQuery.parameters(model),
                        DocumentQuery.controls(model)
                    )
                case .settings:
                    return surface.render(
                        surface,
                        DocumentQuery.parameters(model),
                        DocumentQuery.controls(model)
                    )
            }
        }
        .frame(maxHeight: .infinity)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}

