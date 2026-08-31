import Foundation
import SwiftUI


@Observable final class OutlinePanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init()
    var surface: PanelSurface = .outline

    enum PanelSurface: String, CaseIterable, Identifiable {
        case outline
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String { "square.fill.text.grid.1x2" }
    }

    func parameters(_ model: any Model) -> Params {
        .init(
            panel: .init(
                key: .outline,
                sizing: .init(size: CGSize(width: 360, height: 640), min: .init(CGSize(width: 360, height: 640),)),
                dismissal: [.escape, .outsideClick],
                resizable: true,
                pinnable: true
            )
        )
    }

    func surface(_ model: any Model) -> some View {
        AnySurface(panel: self, model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
