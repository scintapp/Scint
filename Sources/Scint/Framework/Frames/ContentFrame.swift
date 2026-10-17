import Foundation
import SwiftUI
import ScintComponents


@Observable final class ContentFrame: Frame {
    var state: StateContainer = .init()
    var surface: HostSurface = .inbox

    enum HostSurface: String, CaseIterable, Identifiable {
        case inbox, library, projects, tasks
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    func controls(_ model: any Model) -> Controls {
        switch model.session.selection.root {
            case model.session.agenda: AgendaMapper.controls(model)
            default: .init()
        }
    }

    func parameters(_ model: any Model) -> Params {
        switch model.session.selection.root {
            case model.session.agenda: AgendaMapper.parameters(model)
            default: .init()
        }
    }

    func surface(_ model: AppModel) -> some View {
        ZStack {
            if let root = model.session.selection.root {
                switch root {
                    case model.session.agenda: AgendaContent(host: self, model: model)
                    case model.session.library: LibraryContent(host: self, model: model)
                    case model.session.spaces: ProjectContent(host: self, model: model)
                    default: NoReference(ref: root, title: "Nothing Here")
                }
            }
        }
        .background(Style.Background.canvas)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .navigation) { NavigationButtons(model: model) }
            ToolbarSpacer(.flexible, placement: .automatic)
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { InspectorPicker() }
        }
    }
}
