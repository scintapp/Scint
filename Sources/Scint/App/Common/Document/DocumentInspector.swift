import Foundation
import SwiftUI


struct DocumentInspector: Surface {
    var panel: any Panel
    var model: any Model
    var surface: InspectorPanel.PanelSurface

    var body: some View {
        let view = AnySurface(panel: panel, model: model)

        Group {
            switch surface {
                case .outline:
                    view.render(
                        view,
                        DocumentQuery.parameters(model),
                        DocumentQuery.controls(model)
                    )
                case .settings:
                    view.render(view,
                        DocumentQuery.parameters(model),
                        DocumentQuery.controls(model)
                    )
                case .context:
                    EmptyView()
            }
        }
        .frame(maxHeight: .infinity)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}

