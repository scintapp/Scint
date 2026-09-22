import Foundation
import SwiftUI
import ScintComponents


@Observable final class InspectorPanel: Panel {
    var state: PanelState = .init()
    var surface: PanelSurface = .outline

    enum PanelSurface: String, CaseIterable, Identifiable {
        case context, outline, settings

        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var symbol: String {
            switch self {
                case .context: "text.bubble"
                case .outline: "square.fill.text.grid.1x2"
                case .settings: "gearshape"
            }
        }
    }

    func controls(_ model: any Model) -> Controls {
        SpaceOutlineQuery.controls(model)
    }

    func parameters(_ model: any Model) -> Params {
        SpaceOutlineQuery.parameters(model)
    }

    func surface(_ model: any Model) -> some View {
        let hole = PanelHole(insets: EdgeInsets(top: 9, leading: 0, bottom: 9, trailing: 9), radius: Metrics.inspectorHoleRadius)

        return VStack {
            switch surface {
                case .context:
                    EmptyView()
                case .outline:
                    SpaceOutline(panel: self, model: model)
                case .settings:
                    SpaceSettings(panel: self, model: model)
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
