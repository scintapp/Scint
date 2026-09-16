import Foundation
import SwiftUI


struct InspectorPicker: View {
    @Environment(ScintModel.self) var scint
    var panel: InspectorPanel { scint.app.studio.inspector }
    let model: any Model

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
        .foregroundStyle(Style.Foreground.primary, Style.Foreground.secondary, Style.Foreground.faint)
        .tint(Style.Background.control)
    }
}

@Observable final class InspectorPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init()
    var surface: PanelSurface = .harness

    enum PanelSurface: String, CaseIterable, Identifiable {
        case harness, transcript, material

        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var symbol: String {
            switch self {
                case .harness: "gearshape"
                case .transcript: "text.bubble"
                case .material: "text.alignleft"
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        let hole = PanelHole(insets: EdgeInsets(top: 9, leading: 0, bottom: 9, trailing: 9), radius: Style.Shape.holeRadius)

        return VStack {
            switch surface {
                case .harness: HarnessSurface(panel: self, model: model)
                case .transcript: TranscriptSurface(panel: self, model: model)
                case .material: MaterialSurface(panel: self, model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding([.trailing, .vertical], 9)
        .background {
            Color.clear
                .glassEffect(.clear.tint(Style.Background.base.opacity(0.75)), in: hole.inset(by: -2))
                .opacity(0.5)
                .ignoresSafeArea()
        }
        .overlay {
            ZStack {
                PanelFrame(hole: hole).fill(Style.Background.base, style: FillStyle(eoFill: true))
                hole.strokeBorder(Style.Border.handle, lineWidth: 1).opacity(0.5)
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
