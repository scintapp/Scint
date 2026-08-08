import Foundation
import SwiftUI


@Observable @MainActor final class ScintModel {
    var editor: EditorModel
    var studio: StudioModel
    var panels: PanelsModel
    var server: ServerModel

    init() {
        self.editor = .init(Self.restore(for: .editor))
        self.studio = .init(Self.restore(for: .studio))
        self.panels = .init(Self.restore(for: .panels))
        self.server = .init()
    }

    func load() async {
        await SampleData.load(editor.session.workspace, for: .editor)
        await SampleData.load(studio.session.workspace, for: .studio)
        await SampleData.load(panels.session.workspace, for: .panels)
        await Runtime.shared.save()
        await server.start()
    }

    func toggleActions() { panels.toggleActions() }
    func toggleAssistant() { panels.toggleAssistant() }
    func toggleOutline() { panels.toggleOutline() }
    func toggleSearch() { panels.toggleSearch() }
    func toggleTasks() { panels.toggleTasks() }

    static func persist(_ session: Session, for key: AppKey) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: key.value)
    }

    static func restore(for key: AppKey) -> Session {
        if let data = UserDefaults.standard.data(forKey: key.value),
           let session = try? JSONDecoder().decode(Session.self, from: data),
           Workspace.with(session.workspace, { _ in true }) == true { return session }
        let workspace = Workspace.new(key.value)
        let session = Session(workspace)
        persist(session, for: key)
        return session
    }
}
