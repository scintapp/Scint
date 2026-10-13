import Foundation
import SwiftUI
import ScintComponents
import ScintRuntime


@Observable final class InspectorFrame: Frame {
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

    func controls(_ model: any Model) -> Controls {
        switch surface {
            case .outline: InspectorOutline.controls(model)
            case .settings: InspectorSettings.controls(model)
        }
    }

    func parameters(_ model: any Model) -> Params {
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
                    .glassEffect(.clear, in: hole.inset(by: -2))
                    .blendMode(.color)
            }
            .overlay {
                ZStack {
                    HostShape(hole: hole).fill(Style.Background.canvas, style: FillStyle(eoFill: true))
                    hole.strokeBorder(Style.Border.base, lineWidth: 1)
                    hole.stroke(.black, lineWidth: 0.5)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            .toolbar { ToolbarSpacer(.fixed, placement: .automatic) }
    }
}

