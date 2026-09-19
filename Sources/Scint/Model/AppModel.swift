import Foundation
import SwiftUI



@Observable @MainActor final class AppModel {
    var editor: EditorModel
    var studio: StudioModel
    var panels: PanelModel

    init(_ data: AppData) {
        self.editor = .init(Session(data))
        self.studio = .init(Session(data))
        self.panels = .init()
    }

    func model(for key: ModelKey) -> any Model {
        switch key {
            case .editor: editor
            case .studio: studio
        }
    }

    func panel(for key: PanelKey) -> any Panel {
        switch key {
            case .actions: panels.actions
            case .input: panels.input
            case .search: panels.search
        }
    }
}
