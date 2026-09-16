import Foundation
import SwiftUI


@Observable @MainActor final class AppModel {
    var editor: EditorModel
    var studio: StudioModel

    init() {
        self.editor = .init(.init())
        self.studio = .init(.init())
    }

    func app(for key: ModelKey) -> any Model {
        switch key {
            case .editor: editor
            case .studio: studio
        }
    }
}
