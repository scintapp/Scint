import Foundation
import SwiftUI


@Observable @MainActor final class StudioModel: Model {
    var canvas: CanvasPanel
    var assistant: AssistantPanel
    var navigator: NavigatorPanel
    var session: Session
    var scint: ScintModel

    init(_ scint: ScintModel, session: Session) {
        self.scint = scint
        self.canvas = .init(scint)
        self.assistant = .init()
        self.navigator = .init()
        self.session = session
    }
}

@Observable @MainActor final class EditorModel: Model {
    var scint: ScintModel
    var editor: EditorPanel
    var navigator: NavigatorPanel
    var session: Session

    init(_ scint: ScintModel, session: Session) {
        self.editor = .init()
        self.navigator = .init()
        self.session = session
        self.scint = scint
    }
}

@Observable @MainActor final class ScintModel {
    private(set) var models: [ModelKey: any Model] = [:]
    var host: HostModel = .init()
    var panels: PanelManager = .init()
    var editor: EditorModel { model(for: .editor) as! EditorModel }
    var studio: StudioModel { model(for: .studio) as! StudioModel }

    func model(for key: ModelKey) -> any Model { models[key]! }
    func panel(for key: PanelKey) -> any Panel { panels.panel(for: key) }

    func load() async {
        let session = Self.read(.studio)
        models[.editor] = EditorModel(self, session: session)
        models[.studio] = StudioModel(self, session: session)

        CallbackRouter.register(CallbackTrigger.action) { request in
            CallbackTrigger.handle(request)
        }

        CallbackRouter.register(CallbackRouter.openAction) { [weak self] request in
            guard let self, let ref = request.reference else { return false }
            return ReferenceActions.open(ref, in: studio)
        }

        ObserveInterfaces.load()
        IntentInterfaces.load()

        var seeded = await SampleData.load(studio.session.space, for: .studio)
        seeded = await SampleData.load(studio.session.space, for: .editor)
        if seeded { await Runtime.shared.save() }
        await host.load()
    }

    func toggle(_ key: PanelKey, _ source: ModelKey) {
        let defaults = PanelParams(key: key, sizing: .init(size: CGSize(width: 640, height: 480)))
        let panel = panel(for: key)
        let model = model(for: source)
        let params = panel.parameters(model).panel ?? defaults
        let key = params.key
        let view = panel.surface(model) as! any View
        panels.toggle(key, params, view) { presented in panel.state.presented = presented }
    }

    static func write(_ session: Session, for key: ModelKey) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: key.namespace)
    }

    static func read(_ key: ModelKey) -> Session {
        if let data = UserDefaults.standard.data(forKey: key.namespace),
           let session = try? JSONDecoder().decode(Session.self, from: data),
           Space.with(session.space, { $0.space == nil }) == true { return Session(session.space) }
        let roots = Runtime.shared.spaces.sorted { $0.id.uuidString < $1.id.uuidString }
        let session = Session(roots.first ?? Space.new(key.namespace))
        write(session, for: key)
        return session
    }
}
