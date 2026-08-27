import SwiftUI


@Observable final class TasksPanel: Panel {
    var state: PanelState = .init()
    var surface: PanelSurface = .tasks

    enum PanelSurface: String, CaseIterable, Identifiable {
        case tasks
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String { "checkmark.app" }
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
        TasksSurface(panel: self, model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
