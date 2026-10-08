import Foundation
import SwiftUI
import ScintComponents


@Observable final class AppContent: Frame {
    var state: StateContainer = .init()
    var surface: HostSurface = .inbox

    enum HostSurface: String, CaseIterable, Identifiable {
        case inbox, library, projects, tasks
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    func surface(_ model: AppModel) -> some View {
        ZStack {
            if let root = model.session.selection.root {
                switch root {
                    case model.session.inbox: InboxContent(host: self, model: model)
                    case model.session.library: LibraryContent(host: self, model: model)
                    case model.session.projects: ProjectContent(host: self, model: model)
                    case model.session.tasks: TasksContent(host: self, model: model)
                    default: NoReference(ref: root, title: "Nothing Here")
                }
            }
        }
        .background(Style.Background.canvas)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .navigation) { NavigationButtons(model: model)  }
            ToolbarSpacer(.flexible, placement: .automatic)
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { InspectorPicker() }
        }
    }
}
