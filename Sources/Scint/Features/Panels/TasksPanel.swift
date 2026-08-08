import Foundation
import SwiftUI


@Observable final class TasksPanel: Panel {
    var state: StateContainer = .init()

    func surface(_ model: any Model) -> some View {
        EmptyView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
