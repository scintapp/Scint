import SwiftUI
import ScintComponents
import ScintRuntime
import ScintServer


enum PanelKey: String, Identifiable, CaseIterable {
    case actions, search
    var id: String { self.rawValue }
}

enum ModelKey: String, Identifiable, CaseIterable {
    case app, panels
    var id: String { self.rawValue }
}

@Observable @MainActor final class ScintModel {
    var app: AppModel
    var panels: PanelModel
    var data: DataModel

    init(_ data: DataModel) {
        let app = AppModel(Session(data))
        self.panels = PanelModel(app, Session(data))
        self.app = app
        self.data = data
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
            guard !ActionProvider.ReferenceAction.open(ref) else { return }
            model(for: .app).select(ref)
        }
    }

    func panel(_ key: PanelKey, _ source: ModelKey) { panels.toggle(key) }

    func model(for key: ModelKey) -> Model {
        switch key {
            case .app: app
            case .panels: panels
        }
    }
}
