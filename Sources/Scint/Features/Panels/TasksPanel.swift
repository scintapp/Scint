import SwiftUI


@Observable final class TasksPanel: Panel {
    var key: AppKey = .studio
    var state: AppState = .init()

    func surface(_ model: any Model) -> some View {
        ComposeSurface(host: self, model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
