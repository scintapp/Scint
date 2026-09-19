import Foundation
import ScintComponents
import SwiftUI


struct InspectorPicker: View {
    @Environment(ScintModel.self) var scint
    var panel: InspectorPanel { scint.app.studio.inspector }

    private func selection(for surface: InspectorPanel.PanelSurface) -> Binding<Bool> {
        Binding(
            get: { panel.state.presented && panel.surface == surface },
            set: { selected in
                if selected {
                    panel.surface = surface
                    panel.state.presented = true
                } else if panel.surface == surface {
                    panel.state.presented = false
                }
            }
        )
    }

    var body: some View {
        ControlGroup {
            ForEach(InspectorPanel.PanelSurface.allCases) { surface in
                Toggle(isOn: selection(for: surface)) {
                    Image(systemName: surface.symbol)
                }
            }
        }
        .controlGroupStyle(.navigation)
        .foregroundStyle(Style.Foreground.primary, Style.Foreground.primary, Style.Foreground.secondary)
        .tint(Style.Background.selection)
    }
}

@Observable final class InspectorPanel: Panel {
    var state: PanelState = .init()
    var surface: PanelSurface = .materials

    enum PanelSurface: String, CaseIterable, Identifiable {
        case materials, transcripts, settings

        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var symbol: String {
            switch self {
                case .materials: "text.alignleft"
                case .transcripts: "text.bubble"
                case .settings: "switch.2"
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        let hole = PanelHole(insets: EdgeInsets(top: 9, leading: 0, bottom: 9, trailing: 9), radius: Metrics.inspectorHoleRadius)

        return VStack {
            switch surface {
                case .materials: MaterialInspector(panel: self, model: model)
                case .transcripts: TranscriptContent(panel: self, model: model)
                case .settings: HarnessSidebar(panel: self, model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding([.trailing, .vertical], 9)
        .background {
            Color.clear
                .glassEffect(.clear.tint(Style.Background.canvas.opacity(0.75)), in: hole.inset(by: -2))
                .opacity(0.5)
                .ignoresSafeArea()
        }
        .overlay {
            ZStack {
                PanelFrame(hole: hole).fill(Style.Background.canvas, style: FillStyle(eoFill: true))
                hole.strokeBorder(Style.Border.hairline, lineWidth: 1).opacity(0.5)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .toolbar {
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { }
        }
    }
}
