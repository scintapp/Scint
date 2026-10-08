import Foundation
import SwiftUI
import ScintComponents
import ScintRuntime


struct InspectorPicker: View {
    @Environment(ScintModel.self) var scint
    var frame: AppInspector { scint.app.inspector }

    private func selection(for surface: AppInspector.HostSurface) -> Binding<Bool> {
        Binding(
            get: { frame.state.presented && frame.surface == surface },
            set: { selected in
                if selected {
                    frame.surface = surface
                    frame.state.presented = true
                } else if frame.surface == surface {
                    frame.state.presented = false
                }
            }
        )
    }

    var body: some View {
        ControlGroup {
            ForEach(AppInspector.HostSurface.allCases) { surface in
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

@Observable final class AppInspector: Frame {
    var state: StateContainer = .init()
    var surface: HostSurface = .outline
    let hole = Cutout(insets: .init(top: 9, leading: 0, bottom: 9, trailing: 9))

    enum HostSurface: String, CaseIterable, Identifiable {
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

    func controls(_ model: AppModel) -> Controls {
        switch surface {
            case .outline: InspectorOutline.controls(model)
            case .settings: InspectorSettings.controls(model)
        }
    }

    func parameters(_ model: AppModel) -> Params {
        switch surface {
            case .outline: InspectorOutline.parameters(model)
            case .settings: InspectorSettings.parameters(model)
        }
    }

    func surface(_ model: AppModel) -> some View {
        let inspector = AnySurface(host: self, model: model)

        return inspector.render(inspector, parameters(model), controls(model))
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
                    HostShape(hole: hole).fill(Style.Background.canvas, style: FillStyle(eoFill: true))
                    hole.strokeBorder(Style.Border.base, lineWidth: 1)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            .toolbar { ToolbarSpacer(.fixed, placement: .primaryAction) }
    }
}

