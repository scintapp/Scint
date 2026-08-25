import Foundation
import SwiftUI


@Observable final class OutlinePanel: Panel {
    var state: PanelState = .init()
    var surface: OutlineSurface = .composer

    enum OutlineSurface: String, CaseIterable, Identifiable {
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

    func parameters(_ model: any Model) -> Params {
        .init(
            panel: .init(
                key: .outline,
                sizing: .init(size: CGSize(width: 360, height: 520), min: .init(CGSize(width: 360, height: 520),)),
                dismissal: [.escape, .outsideClick],
                resizable: true,
                pinnable: true
            )
        )
    }

    func surface(_ model: any Model) -> some View {
        EmptyView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
