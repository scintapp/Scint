import SwiftUI


@Observable final class TasksPanel: Panel {
    var state: StateContainer = .init()

    func surface(_ model: any Model) -> some View {
        ComposeSurface(panel: self, model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
