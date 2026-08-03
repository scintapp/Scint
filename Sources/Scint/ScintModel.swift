import Foundation
import SwiftUI


@Observable @MainActor final class ScintModel {
    var actions: Actions
    var studio: StudioModel
    var server: ServerModel
    var panels: PanelController

    init(_ workspaces: [Reference]) {
        func workspace(_ framing: Framing) -> Reference {
            if let ref = workspaces.first(where: { $0.descriptor.framing == framing }) { return ref }
            return Workspace.new("\(framing)".capitalized, framing: framing)
        }

        self.actions = .init()
        self.panels = .init()
        self.server = .init()
        self.studio = .init(workspace(.studio))
    }

    func load() async {
        await SampleData.load(studio.session.workspace)
        do { try await Runtime.shared.save() }
        catch { print(error) }
        await server.start()
    }

    func showActions() {
        let parameters = actions.parameters(studio)
        guard let panel = parameters.panel else { return }
        panels.show(parameters.id, parameters: panel, view: actions.panel(studio)) {
            [weak actions = actions] presented in actions?.state.presented = presented
        }
    }

    func toggleActions() {
        let parameters = actions.parameters(studio)
        guard let panel = parameters.panel else { return }
        panels.toggle(parameters.id, parameters: panel, view: actions.panel(studio)) {
            [weak actions = actions] presented in actions?.state.presented = presented
        }
    }

    func handle(_ url: URL) -> Runtime.Callback? {
        do {
            let callback = try Runtime.shared.handle(url)
            switch callback {
                case .open(let ref):
                    studio.open(ref)
                case .eval:
                    break
                case .dispatch(_, _, let error):
                    if let error { print(error) }
                case .run(_, _, let error):
                    if let error { print(error) }
                case .search(let results):
                    actions.query = results.query
                    showActions()
            }
            return callback
        } catch {
            print(error)
            return nil
        }
    }
}
