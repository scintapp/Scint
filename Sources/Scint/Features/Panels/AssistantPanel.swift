import Foundation
import SwiftUI


@Observable final class AssistantPanel: Panel {
    var state: StateContainer = .init()

    func surface(_ model: any Model) -> some View {
        ComposerSurface(panel: self, model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
