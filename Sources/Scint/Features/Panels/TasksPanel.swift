import SwiftUI


@Observable final class TasksPanel: Panel {
    var state: AppState = .init()

    func parameters(_ model: any Model) -> Params {
        .init(
            panel: .init(
                key: .tasks,
                size: CGSize(width: 420, height: 560),
                minimumSize: CGSize(width: 320, height: 320),
                layout: .float,
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
