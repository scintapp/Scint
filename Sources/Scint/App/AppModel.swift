import SwiftUI
import ScintComponents


@Observable @MainActor final class AppModel: Model {
    var content: AppContent
    var inspector: AppInspector
    var navigator: AppNavigator
    var session: Session

    init(_ session: Session) {
        self.content = .init()
        self.inspector = .init()
        self.navigator = .init()
        self.session = session
    }
}
