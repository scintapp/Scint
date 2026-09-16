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
    var surface: PanelSurface = .compose

    enum PanelSurface: String, CaseIterable, Identifiable {
        case compose, execute

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String {
            switch self {
                case .compose: "checkmark.app"
                case .execute: "rectangle.stack"
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        ZStack(alignment: .top) {
            switch surface {
                case .compose:
                    CanvasSurface(panel: self, model: model)
                case .execute:
                    ActivitySurface(panel: self, model: model, onOpen: {})
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
