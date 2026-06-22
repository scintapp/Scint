import AgencyRuntime
import Foundation
import SwiftUI


@Observable @MainActor final class AgencyModel {
    var artifacts: ArtifactManager
    var panels: PanelsModel
    var session: SessionModel
    var folio: FolioModel
    var studio: StudioModel

    init(_ space: Reference) {
        self.artifacts = .init(workspace: space)
        self.panels = .init()
        self.folio = .init()
        self.studio = .init()
        self.session = .init(space)
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

    func open(_ ref: Reference) { session.open(ref) }

    @discardableResult func forward() -> Selection? { session.forward() }
    @discardableResult func backward() -> Selection? { session.back() }

    func actions() { }

    func compose(_ space: Reference) { }

    func search(_ query: String, limit: Int) -> SearchResults { Runtime.shared.search(query, limit: limit) }
}
