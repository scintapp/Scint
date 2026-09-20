import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


@Observable final class ActionsPanel: Panel {
    var state: PanelState = .init()
    var surface: PanelSurface = .composer

    enum PanelSurface: String, CaseIterable, Identifiable {
        case composer, editor

        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var symbol: String {
            switch self {
                case .composer: "square.fill.text.grid.1x2"
                case .editor: "square.and.pencil"
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        AnySurface(panel: self, model: model)
    }
}
