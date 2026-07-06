import AgencyRuntime
import Foundation
import SwiftUI


@Observable @MainActor final class AgencyModel {
    var artifacts: ArtifactManager
    var session: SessionModel
    var studio: StudioModel
    var library: LibraryModel
    var panels: PanelController

    init(_ space: Reference) {
        self.artifacts = .init(workspace: space)
        self.library = .init()
        self.studio = .init()
        self.session = .init(space)
        self.panels = .init()
    }

    func load() async {
        await load(Runtime.shared.workspace)
        await SampleData.load()
        do { try await Runtime.shared.save() }
        catch { print(error) }
    }

    func load(_ workspace: Reference) async {
        session.load(workspace)
        await artifacts.load(runtime: Runtime.shared)
    }

    func focus(_ ref: Reference?) { session.focus(ref) }

    func select(_ ref: Reference) { session.select(ref) }

    func select(_ ref: Reference, entry: UUID?, url: URL?) { session.select(ref, entry: entry, url: url) }

    func open(_ ref: Reference) {
        guard session.open(ref) else { return }

        if ref.type is Sheet.Type {
            session.select(ref)
            session.focus(ref)
            studio.canvas.model = .editor
            studio.editor.model = .detail
        }
    }

    func search(_ query: String, limit: Int) -> SearchResults { Runtime.shared.search(query, limit: limit) }

    @discardableResult
    func compose(_ space: Reference) -> AgencyRuntime.Process? { Runtime.shared.context(for: space) }
}
