import Foundation
import SwiftUI
import ScintComponents
import ScintRuntime
import ScintServer


enum PanelKey: String, Identifiable, CaseIterable {
    case actions, input, search
    var id: String { self.rawValue }
}

enum ModelKey: String, Identifiable, CaseIterable {
    case app
    var id: String { self.rawValue }
}

@Observable @MainActor final class ScintModel {
    var app: AppModel
    var panels: PanelModel
    var data: DataModel

    init(_ data: DataModel) {
        self.app = .init(Session(data))
        self.panels = .init()
        self.data = data
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

    var openURL: OpenURLAction {
        OpenURLAction { url in
            guard url.scheme?.lowercased() == Reference.Link.scheme else { return .systemAction }
            self.open(url)
            return .handled
        }
    }

    func open(_ url: URL?) {
        CallbackHandler.handle(url, in: data.app) { ref in
            guard !ReferenceAction.open(ref) else { return }
            model(for: .app).select(ref)
        }
    }

    func model(for key: ModelKey) -> any Model {
        switch key {
            case .app: app
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
