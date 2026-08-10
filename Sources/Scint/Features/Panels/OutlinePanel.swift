import Foundation
import SwiftUI


@Observable final class OutlinePanel: Panel {
    var key: AppKey = .editor
    var state: AppState = .init()

    func surface(_ model: any Model) -> some View {
        EmptyView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
