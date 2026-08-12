import Foundation
import SwiftUI


@Observable final class AssistantPanel: Panel {
    var state: PanelState = .init()

    func parameters(_ model: any Model) -> Params {
        .init(
            panel: .init(
                key: .assistant,
                sizing: .init(
                    size: CGSize(width: 520, height: 640),
                    min: .init(CGSize(width: 360, height: 360))
                ),
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
