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
            if let root = model.session.selection.root {
                switch root {
                    case model.session.inbox:
                        TranscriptInbox(panel: self, model: model)
                    case model.session.drafts:
                        DocumentDrafts(panel: self, model: model)
                    case model.session.tasks:
                        SpaceSchedule(panel: self, model: model)
                    case model.session.space:
                        SpaceContent(panel: self, model: model)
                    case model.session.library:
                        if let _ = model.session.opened.document { DocumentContent(panel: self, model: model) }
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
