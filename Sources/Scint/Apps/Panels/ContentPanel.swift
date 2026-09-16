import Foundation
import SwiftUI


struct ContentPicker: View {
    @Environment(ScintModel.self) var scint
    var panel: ContentPanel { scint.app.studio.content }
    let model: any Model

    private var selection: Binding<ContentPanel.PanelSurface> {
        Binding(get: { panel.surface }, set: { panel.surface = $0 })
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
    var viewport: CanvasViewport = .init()
    var axis: CanvasAxis = .vertical

    enum PanelSurface: String, CaseIterable, Identifiable {
        case activity, canvas

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String {
            switch self {
                case .activity: "rectangle.stack"
                case .canvas: "checkmark.app"
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        ZStack(alignment: .top) {
            switch surface {
                case .activity:
                    EmptyView()

                case .canvas:
                    CanvasSurface(panel: self, model: model)
                        .safeAreaInset(edge: .bottom) {
                            HStack(alignment: .bottom) {
                                CanvasMap(panel: self, model: model)
                                Spacer()
                                CanvasControl { CanvasPresentation(panel: self) }
                                CanvasControl { CanvasZoom(viewport: viewport) }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                        }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) { NavigationButtons(model: model)  }
            ToolbarSpacer(.flexible, placement: .automatic)
            ToolbarItem(placement: .principal) { ContentPicker(model: model)  }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { InspectorPicker(model: model) }
        }
    }
}
