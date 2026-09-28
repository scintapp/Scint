import Foundation
import SwiftUI
import ScintComponents
import ScintRuntime


struct InspectorPicker: View {
    @Environment(ScintModel.self) var scint
    var panel: StudioInspector { scint.studio.inspector }

    private func selection(for surface: StudioInspector.PanelSurface) -> Binding<Bool> {
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
            ForEach(StudioInspector.PanelSurface.allCases) { surface in
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

@Observable final class StudioInspector: Panel {
    var state: PanelState = .init()
    var surface: PanelSurface = .outline

    enum PanelSurface: String, CaseIterable, Identifiable {
        case outline, settings

        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var symbol: String {
            switch self {
                case .outline: "square.text.square"
                case .settings: "switch.2"
            }
        }
    }

    @ViewBuilder func inspector(_ model: any Model) -> some View {
        let session = model.session
        switch (surface, session.selection.root) {
            case (.outline, session.projects):
                SpaceMapper.outline(self, model)
            case (.settings, session.projects):
                SpaceMapper.settings(self, model)
            case (.outline, session.tasks):
                TaskSettings(panel: self, model: model)
            case (.settings, session.tasks):
                TaskSettings(panel: self, model: model)
            case (.outline, session.inbox), (.outline, session.library):
                DocumentOutline(panel: self, model: model)
            case (.settings, session.inbox), (.settings, session.library):
                DocumentSettings(panel: self, model: model)
            case (_, let root):
                NoReference(ref: root, title: "Nothing Here")
        }
    }

    func surface(_ model: any Model) -> some View {
        let hole = PanelHole(insets: EdgeInsets(top: 9, leading: 0, bottom: 9, trailing: 9), radius: Metrics.inspectorHoleRadius)
        return VStack { inspector(model) }
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
