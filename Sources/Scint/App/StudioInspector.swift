import Foundation
import SwiftUI
import ScintComponents
import ScintRuntime


struct InspectorPicker: View {
    @Environment(ScintModel.self) var scint
    var panel: InspectorPanel { scint.studio.inspector }

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
        .overlay {
            Style.Background.canvas
                .opacity(0.4)
                .blendMode(.overlay)
                .allowsHitTesting(false)
        }
    }
}

@Observable final class InspectorPanel: Panel {
    var state: PanelState = .init()
    var surface: PanelSurface = .outline

    enum PanelSurface: String, CaseIterable, Identifiable {
        case  context, outline, settings

        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var symbol: String {
            switch self {
                case .outline: "text.badge.checkmark"
                case .settings: "switch.2"
                case .context: "text.bubble"
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        let hole = PanelHole(insets: EdgeInsets(top: 9, leading: 0, bottom: 9, trailing: 9), radius: Metrics.inspectorHoleRadius)
        var ref: Reference? { model.session.selection.root }
        return VStack {
            if let ref {
                switch ref {
                    case model.session.inbox: DocumentInspector(panel: self, model: model)
                    case model.session.library: DocumentInspector(panel: self, model: model)
                    case model.session.projects: SpaceInspector(panel: self, model: model)
                    case model.session.tasks: TaskInspector(panel: self, model: model)
                    default: NoReference(ref: ref, title: "Nothing Here")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding([.trailing, .vertical], 9)
        .background {
            Color.clear
                .glassEffect(.regular, in: hole.inset(by: -2))
                .overlay { Color.clear.blendMode(.color).opacity(0.4) }
                .overlay { Style.Background.canvas.opacity(0.6) }
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
        }
    }
}
