import Foundation
import SwiftUI


struct ContentPicker: View {
    @Environment(ScintModel.self) var scint
    var content: ContentPanel { scint.app.studio.content }
    var navigator: NavigatorPanel { scint.app.studio.navigator }

    private var selection: Binding<ContentPanel.PanelSurface> {
        Binding(get: { content.surface }, set: { content.surface = $0 })
    }

    var body: some View {
        Picker("Content", selection: selection) {
            ForEach(ContentPanel.PanelSurface.allCases) { surface in
                Text(surface.label).tag(surface)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .foregroundStyle(Style.Foreground.primary, Style.Foreground.secondary, Style.Foreground.faint)
        .tint(Style.Background.control)
    }
}

@Observable final class ContentPanel: Panel {
    var state: PanelState = .init()
    var surface: PanelSurface = .canvas

    enum PanelSurface: String, CaseIterable, Identifiable {
        case canvas, drafts, outlines, activity

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String {
            switch self {
                case .canvas: "checkmark.app"
                case .drafts: "rectangle.stack"
                case .outlines: "tray"
                case .activity: "tray"
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        var ref: Reference? {
            guard let ref = model.session.selection.structure, Space.with(ref, { $0 }) != nil
            else { return nil }
            return ref
        }

        return ZStack(alignment: .top) {
            Group {
                switch surface {
                    case .activity: SpaceSurface(panel: self, model: model)
                    case .canvas: CanvasSurface(panel: self, model: model)
                    case .drafts: DraftsSurface(panel: self, model: model)
                    case .outlines: DraftsSurface(panel: self, model: model)

                }
            }
                .toolbar {
                    ToolbarItem(placement: .navigation) { NavigationButtons(model: model)  }
                    ToolbarSpacer(.flexible, placement: .automatic)
                    ToolbarItem(placement: .principal) { ContentPicker() }
                    ToolbarSpacer(.flexible, placement: .primaryAction)
                    ToolbarItem(placement: .primaryAction) { InspectorPicker() }
                }
        }
    }
}
