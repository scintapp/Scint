import Foundation
import SwiftUI


@Observable final class ActionsPanel: Panel {
    var state: PanelState = .init()
    var surface: ActionsSurface = .composer

    enum ActionsSurface: String, CaseIterable, Identifiable {
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

    func controls(_ model: any Model) -> Controls {
        ActionsQuery.controls(model)
    }

    func parameters(_ model: any Model) -> Params {
        ActionsQuery.parameters(model)
    }

    func surface(_ model: any Model) -> some View {
        AnySurface(panel: self, model: model)
    }
}
