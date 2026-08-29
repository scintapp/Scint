import Foundation
import SwiftUI


@Observable final class DetailPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init()
    var surface: PanelSurface = .detail

    enum PanelSurface: String, CaseIterable, Identifiable {
        case detail
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String { "square.fill.text.grid.1x2" }
    }

    func parameters(_ model: any Model) -> Params {
        .init(
            panel: .init(
                key: .detail,
                sizing: .init(size: CGSize(width: 340, height: 540), min: .init(CGSize(width: 340, height: 540),)),
                dismissal: [.escape, .outsideClick],
                resizable: true,
                pinnable: true
            )
        )
    }

    func surface(_ model: any Model) -> some View {
        DetailSurface(panel: self, model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
