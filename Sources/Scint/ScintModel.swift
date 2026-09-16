import Foundation
import SwiftUI


@Observable @MainActor final class ScintModel {
    var app: AppModel
    var panels: PanelModel
    var host: HostModel

    init() {
        self.app = .init()
        self.panels = .init()
        self.host = .init()
    }

    func window(for key: ModelKey) -> any Model { app.app(for: key) }
    func panel(for key: PanelKey) -> any Panel { panels.panel(for: key) }

    func load() async {
        CallbackRouter.register(CallbackTrigger.action) { request in
            CallbackTrigger.handle(request)
        }

        CallbackRouter.register(CallbackRouter.openAction) { [weak self] request in
            guard let self, let ref = request.reference else { return false }
            if ReferenceAction.open(ref) { return true }
            window(for: .studio).select(ref)
            return true
        }

        Harnesses.load()

        var seeded = false
        for space in Runtime.shared.spaces { seeded = await SampleData.load(space) || seeded }
        if seeded { await Runtime.shared.save() }
        await host.load()
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
