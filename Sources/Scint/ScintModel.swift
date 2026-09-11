import Foundation
import SwiftUI



@Observable @MainActor final class StudioModel: Model {
    var content: StudioPanel
    var inspector: InspectorPanel
    var navigator: NavigatorPanel
    var session: Session

    init(_ session: Session) {
        self.content = .init()
        self.inspector = .init()
        self.navigator = .init() 
        self.session = session
    }
}

@Observable @MainActor final class AssistantModel: Model {
    var content: AssistantPanel
    var inspector: InspectorPanel
    var navigator: NavigatorPanel
    var session: Session

    init(_ session: Session) {
        self.content = .init()
        self.inspector = .init()
        self.navigator = .init()
        self.session = session
    }
}

@Observable @MainActor final class EditorModel: Model {
    var content: EditorPanel
    var inspector: InspectorPanel
    var navigator: NavigatorPanel
    var session: Session

    init(_ session: Session) {
        self.content = .init()
        self.inspector = .init()
        self.navigator = .init()
        self.session = session
    }
}

@Observable @MainActor final class ScintModel {
    private(set) var models: [ModelKey: any Model] = [:]
    var host: HostModel = .init()
    var panels: PanelManager = .init()

    var assistant: AssistantModel { model(for: .assistant) as! AssistantModel }
    var editor: EditorModel { model(for: .editor) as! EditorModel }
    var studio: StudioModel { model(for: .studio) as! StudioModel }

    func model(for key: ModelKey) -> any Model { models[key]! }
    func panel(for key: PanelKey) -> any Panel { panels.panel(for: key) }

    func load() async {
        models[.assistant] = AssistantModel(Self.read(.assistant))

        CallbackRouter.register(CallbackTrigger.action) { request in
            CallbackTrigger.handle(request)
        }

        CallbackRouter.register(CallbackRouter.openAction) { [weak self] request in
            guard let self, let ref = request.reference else { return false }
            return ReferenceActions.open(ref, in: assistant)
        }

        var seeded = await SampleData.load(assistant.session.workspace, for: .editor)
        seeded = await SampleData.load(assistant.session.workspace, for: .assistant) || seeded
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
           Workspace.with(session.workspace, { _ in true }) == true { return session }
        let workspace = Workspace.new(key.namespace)
        let session = Session(workspace)
        write(session, for: key)
        return session
    }
}
