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
            if let root = session.selection.root {
                switch root {
                    case session.inbox:
                        TranscriptInbox(panel: self, model: model)
                    case session.activity:
                        SpaceActivity(panel: self, model: model)
                    case session.scheduled:
                        SpaceSchedule(panel: self, model: model)
                    case session.space:
                        SpaceContent(panel: self, model: model)
                    case session.library:
                        if let _ = session.opened.document { DocumentContent(panel: self, model: model) }
                        else { DocumentLibrary(panel: self, model: model) }
                    default:
                        NoReference(ref: root, title: "Nothing Here")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
