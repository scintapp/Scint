import SwiftUI
import ScintComponents


@Observable final class AppModel: Model {
    var content: ContentFrame
    var inspector: Inspector
    var navigator: Navigator
    var session: Session

    init(_ session: Session) {
        self.content = .init()
        self.inspector = .init()
        self.navigator = .init()
        self.session = session
    }
}
