import Foundation
import SwiftUI


@Observable @MainActor final class AppModel {
    var editor: EditorModel
    var studio: StudioModel

    init(_ data: AppData) {
        self.editor = .init(Session(data))
        self.studio = .init(Session(data))
    }

    func app(for key: ModelKey) -> any Model {
        switch key {
            case .editor: editor
            case .studio: studio
        }
    }
}
