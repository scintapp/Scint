import Foundation
import SwiftUI


@Observable @MainActor final class AppModel {
    var editor: EditorModel
    var studio: StudioModel

    init(_ spaces: [Reference]) {
        self.editor = .init(.init(spaces))
        self.studio = .init(.init(spaces))
    }

    func app(for key: ModelKey) -> any Model {
        switch key {
            case .editor: editor
            case .studio: studio
        }
    }
}
