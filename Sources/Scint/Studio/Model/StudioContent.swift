import Foundation
import SwiftUI
import ScintComponents


@Observable final class ContentPanel: Panel {
    var state: PanelState = .init()
    var surface: PanelSurface = .studio

    enum PanelSurface: String, CaseIterable, Identifiable {
        case studio
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    func surface(_ model: any Model) -> some View {
        ZStack {
            if let root = model.session.selection.root {
                switch root {
                    case model.session.inbox: InboxContent(panel: self, model: model)
                    case model.session.library: LibraryContent(panel: self, model: model)
                    case model.session.projects: ProjectContent(panel: self, model: model)
                    case model.session.tasks: TasksContent(panel: self, model: model)
                    default: NoReference(ref: root, title: "Nothing Here")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .navigation) { NavigationButtons(model: model)  }
            ToolbarSpacer(.flexible, placement: .automatic)
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { InspectorPicker() }
        }
    }
}
