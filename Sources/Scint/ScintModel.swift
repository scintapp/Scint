import Foundation
import SwiftUI


enum PanelKey: String, Identifiable, CaseIterable {
    case actions, search, assistant, outline, tasks
    var id: String { self.panel }
    var panel: String { self.rawValue }
    var model: String { "scint" }
    var namespace: String { "\(model).panels.\(panel)" }
}

enum ModelKey: String, Identifiable, CaseIterable {
    case assistant, editor, studio
    var id: String { self.model }
    var app: String { self.rawValue }
    var model: String { "scint" }
    var namespace: String { "\(app).\(model)" }
}

@Observable @MainActor final class StudioModel: Model {
    var assistant: AssistantPanel
    var content: ContentPanel
    var inspector: InspectorPanel
    var navigator: NavigatorPanel
    var session: Session

    init(_ session: Session) {
        self.assistant = .init()
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
        models[.assistant] = AssistantModel(Self.read(.studio))
        models[.editor] = EditorModel(Self.read(.editor))
        models[.studio] = StudioModel(Self.read(.studio))

        ReferenceRouter.register(ReferenceTrigger.action) { request in
            ReferenceTrigger.handle(request)
        }

        ReferenceRouter.register(ReferenceRouter.openAction) { [weak self] request in
            guard let self, let ref = request.reference else { return false }
            return ReferenceActions.open(ref, in: studio)
        }

        var seeded = await SampleData.load(editor.session.workspace, for: .editor)
        seeded = await SampleData.load(studio.session.workspace, for: .studio) || seeded
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
