import Foundation
import SwiftUI
import ScintRuntime


@Observable @MainActor final class ScintModel {
    var data: ScintData
    var studio: StudioModel
    var panels: PanelModel

    init(_ data: ScintData) {
        self.data = data
        self.studio = .init(Session(data))
        self.panels = .init()
    }

    func toggle(_ key: PanelKey, _ source: ModelKey) {
        let defaults = PanelParams(key: key, sizing: .init(size: CGSize(width: 640, height: 480)))
        let panel = panel(for: key)
        let window = model(for: source)
        let params = panel.parameters(window).panel ?? defaults
        let key = params.key
        let view = panel.surface(window) as! any View
        panels.toggle(key, params, view) { presented in panel.state.presented = presented }
    }

    static func write(_ session: Session, for key: ModelKey) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: key.id)
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
