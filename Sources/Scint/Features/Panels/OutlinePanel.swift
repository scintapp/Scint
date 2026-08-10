import Foundation
import SwiftUI


@Observable final class OutlinePanel: Panel {
    var state: AppState = .init()

    func parameters(_ model: any Model) -> Params {
        .init(
            panel: .init(
                key: .outline,
                size: CGSize(width: 360, height: 520),
                minimumSize: CGSize(width: 280, height: 280),
                layout: .float,
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
