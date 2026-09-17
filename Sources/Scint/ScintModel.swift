import Foundation
import SwiftUI


@Observable @MainActor final class ScintModel {
    var app: AppModel
    var data: AppData
    var panels: PanelModel = .init()
    var host: HostModel = .init()

    init(_ data: AppData) {
        self.app = AppModel(data)
        self.data = data
    }

    func window(for key: ModelKey) -> any Model { app.app(for: key) }
    func panel(for key: PanelKey) -> any Panel { panels.panel(for: key) }

    func load() async {
        await callbacks()
        await host.load()
    }

    func callbacks() async {
        CallbackRouter.register(CallbackTrigger.action) { request in CallbackTrigger.handle(request) }
        CallbackRouter.register(CallbackRouter.openAction) { [weak self] request in
            guard let self, let ref = request.reference else { return false }
            if ReferenceAction.open(ref) { return true }
            window(for: .studio).select(ref)
            return true
        }
    }

    func toggle(_ key: PanelKey, _ source: ModelKey) {
        let defaults = PanelParams(key: key, sizing: .init(size: CGSize(width: 640, height: 480)))
        let panel = panel(for: key)
        let window = window(for: source)
        let params = panel.parameters(window).panel ?? defaults
        let key = params.key
        let view = panel.surface(window) as! any View
        panels.toggle(key, params, view) { presented in panel.state.presented = presented }
    }

    static func write(_ session: Session, for key: ModelKey) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: key.id)
    }
}
