import SwiftUI


@Observable final class TasksPanel: Panel {
    var state: PanelState = .init()

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
        ComposeSurface(host: self, model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
