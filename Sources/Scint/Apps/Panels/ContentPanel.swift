import Foundation
import SwiftUI
import ScintComponents

@Observable final class ContentPanel: Panel {
    var state: PanelState = .init()
    var surface: PanelSurface = .studio

    enum PanelSurface: String, CaseIterable, Identifiable {
        case studio, canvas
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    @ViewBuilder private func content(_ model: any Model) -> some View {
        ZStack {
            let session = model.session
            switch surface {
                case .canvas:
                    CanvasSurface(panel: self, model: model)

                case .studio:
                    if let root = session.selection.root {
                        switch root {
                            case session.inbox: InboxSurface(panel: self, model: model)
                            case session.scheduled: ScheduledSurface(panel: self, model: model)
                            case session.library: LibrarySurface(panel: self, model: model)
                            case session.root: SpaceSurface(panel: self,model: model)
                            default: ActivitySurface(panel: self, model: model)
                        }
                    }
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        content(model)
            .toolbar {
                ToolbarItem(placement: .navigation) { NavigationButtons(model: model)  }
                ToolbarSpacer(.flexible, placement: .automatic)
                ToolbarSpacer(.flexible, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { InspectorPicker() }
            }
    }
}
