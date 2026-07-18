import AgencyRuntime
import Foundation
import SwiftUI


@Observable @MainActor final class AgencyFrame: Model {
    var actions: Actions
    var files: FileProvider
    var session: SessionModel

    init(_ workspace: Reference) {
        self.actions = .init()
        self.session = .init(workspace)
        self.files = .init(workspace)
    }
}

@Observable @MainActor final class AgencyModel {
    var agency: AgencyFrame
    var composer: ComposerModel
    var editor: EditorModel
    var library: LibraryModel
    var panels: PanelController
    var studio: StudioModel

    init(_ workspaces: [Reference]) {
        func workspace(_ framing: Framing) -> Reference {
            if let ref = workspaces.first(where: { $0.descriptor.framing == framing }) { return ref }
            return Workspace.new("\(framing)".capitalized, framing: framing).ref
        }

        self.agency = .init(workspace(.agency))
        self.composer = .init(workspace(.composer))
        self.editor = .init(workspace(.editor))
        self.library = .init(workspace(.library))
        self.studio = .init(workspace(.studio))
        self.panels = .init()
    }

    func load() async {
        await SampleData.load(studio.session.workspace)
        do { try await Runtime.shared.save() }
        catch { print(error) }
    }

    func showActions() {
        let parameters = agency.actions.parameters(agency)
        guard let panel = parameters.panel else { return }
        panels.show(parameters.id, parameters: panel, view: agency.actions.surface(agency)) {
            [weak actions = agency.actions] presented in actions?.state.presented = presented
        }
    }

    func toggleActions() {
        let parameters = agency.actions.parameters(agency)
        guard let panel = parameters.panel else { return }
        panels.toggle(parameters.id, parameters: panel, view: agency.actions.surface(agency)) {
            [weak actions = agency.actions] presented in actions?.state.presented = presented
        }
    }

    func handle(_ url: URL) -> Runtime.Callback? {
        do {
            let callback = try Runtime.shared.handle(url)
            switch callback {
                case .open(let ref):
                    agency.open(ref)
                case .dispatch(_, _, let error):
                    if let error { print(error) }
                case .search(let results):
                    agency.actions.query = results.query
                    showActions()
            }
            return callback
        } catch {
            print(error)
            return nil
        }
    }
}
