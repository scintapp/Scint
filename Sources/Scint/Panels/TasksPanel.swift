import SwiftUI


@Observable final class TasksPanel: Panel {
    var state: PanelState = .init()
    var surface: TasksSurface = .composer

    enum TasksSurface: String, CaseIterable, Identifiable {
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
                key: .tasks,
                sizing: .init(size: .init(width: 640, height: 480)),
                dismissal: [.escape, .outsideClick],
                resizable: true,
                pinnable: true
            )
        )
    }

    func surface(_ model: any Model) -> some View {
        ComposeSurface(panel: self, model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
