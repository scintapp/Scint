import SwiftUI
import ScintComponents


@Observable @MainActor final class AppModel: Model {
    var content: ContentPanel
    var inspector: StudioInspector
    var navigator: StudioNavigator
    var session: Session

    init(_ session: Session) {
        self.content = .init()
        self.inspector = .init()
        self.navigator = .init()
        self.session = session
    }
}
