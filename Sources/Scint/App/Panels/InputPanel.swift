import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


@Observable final class InputPanel: Panel {
    var state: StateContainer = .init()
    var surface: PanelSurface = .input

    enum PanelSurface: String, CaseIterable, Identifiable {
        case input

        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var symbol: String { "square.fill.text.grid.1x2" }
    }

    func parameters(_ model: Model) -> Params {
        return .init(
            id: PanelKey.search.id,
            panel: .init(
                key: .input,
                sizing: .init(size: .init(width: 640, height: 90)),
                dismissal: [.escape, .outsideClick],
                movable: true,
                resizable: false,
                pinnable: false
            ),
        )
    }

    func surface(_ model: any Model) -> some View {
        AnySurface(host: self, model: model)
    }
}
