import Foundation
import SwiftUI


@Observable final class OutlinePanel: Panel {
    var state: PanelState = .init()

    func parameters(_ model: any Model) -> Params {
        .init(
            panel: .init(
                key: .outline,
                sizing: .init(
                    size: CGSize(width: 360, height: 520),
                    min: .init(CGSize(width: 360, height: 520),)
                ),
                dismissal: [.escape, .outsideClick],
                resizable: true,
                pinnable: true
            )
        )
    }

    func surface(_ model: any Model) -> some View {
        EmptyView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
