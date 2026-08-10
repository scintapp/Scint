import Foundation
import SwiftUI


@Observable final class AssistantPanel: Panel {
    var state: AppState = .init()

    func parameters(_ model: any Model) -> Params {
        .init(
            panel: .init(
                key: .assistant,
                size: CGSize(width: 520, height: 640),
                minimumSize: CGSize(width: 360, height: 360),
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
