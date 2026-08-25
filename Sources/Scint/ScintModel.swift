import Foundation
import SwiftUI


@Observable @MainActor final class ScintModel {
    private(set) var models: [ModelKey: any Model] = [:]
    var controller: Controller = .init()
    var server: ServerModel = .init()
    var editor: EditorModel { model(for: .editor) as! EditorModel }
    var studio: StudioModel { model(for: .studio) as! StudioModel }

    func model(for key: ModelKey) -> any Model { models[key]! }
    func panel(for key: PanelKey) -> any Panel { controller.panel(for: key) }

    func load() async {
        models[.editor] = EditorModel(Self.restore(.editor))
        models[.studio] = StudioModel(Self.restore(.studio))
        var seeded = await SampleData.load(editor.session.workspace, for: .editor)
        seeded = await SampleData.load(studio.session.workspace, for: .studio) || seeded
        if seeded { await Runtime.shared.save() }
        Observers.install()
        await server.start()
    }

    func toggle(_ key: PanelKey, _ source: ModelKey) {
        let defaults = PanelParams(key: key, sizing: .init(size: CGSize(width: 640, height: 480)))
        let panel = panel(for: key)
        let model = model(for: source)
        let params = panel.parameters(model).panel ?? defaults
        let view = panel.surface(model) as! any View
        controller.toggle(params.key, parameters: params, view: view) {
            presented in panel.state.presented = presented
        }
    }

    static func persist(_ session: Session, for key: ModelKey) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: key.namespace)
    }

    static func restore(_ key: ModelKey) -> Session {
        if let data = UserDefaults.standard.data(forKey: key.namespace),
           let session = try? JSONDecoder().decode(Session.self, from: data),
           Workspace.with(session.workspace, { _ in true }) == true { return session }
        let workspace = Workspace.new(key.namespace)
        let session = Session(workspace)
        persist(session, for: key)
        return session
    }
}
