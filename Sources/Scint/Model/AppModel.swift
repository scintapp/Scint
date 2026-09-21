import Foundation
import SwiftUI



@Observable @MainActor final class AppModel {
    var studio: StudioModel
    var panels: PanelModel

    init(_ data: AppData) {
        self.studio = .init(Session(data))
        self.panels = .init()
    }

    func model(for key: ModelKey) -> any Model {
        switch key {
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
