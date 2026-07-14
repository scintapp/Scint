import AgencyRuntime
import Foundation
import SwiftUI


@Observable @MainActor final class AgencyModel {
    var artifacts: ArtifactManager
    var session: SessionModel
    var studio: StudioModel
    var panels: PanelController

    init(_ space: Reference) {
        self.artifacts = .init(workspace: space)
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

    func compose(_ space: Reference, input: Reference? = nil) -> AgencyRuntime.Process? {
        let request = ServiceRequest(space, parameters(for: input))
        guard let process = Runtime.shared.compose(request) else { return nil }
        return process
    }

    func context(_ space: Reference) -> AgencyRuntime.Process? {
        guard let context = Runtime.shared.context(for: space) else { return nil }
        return context
    }

    func focus(_ ref: Reference?) { session.focus(ref) }

    func select(_ ref: Reference) {
        session.select(ref)
        session.focus(ref)
    }

    func select(_ ref: Reference, entry: UUID?, url: URL?) {
        session.select(ref, entry: entry, url: url)
        session.focus(ref)
    }

    func open(_ ref: Reference) {
        guard session.open(ref) else { return }
        select(ref)
    }

    func search(_ query: String, limit: Int) -> SearchResults { Runtime.shared.search(query, limit: limit) }

    private func parameters(for input: Reference?) -> [AgencyRuntime.Parameter] {
        guard let input else { return [] }
        let text = Sheet.with(input, { $0.rendered.trimmingCharacters(in: .whitespacesAndNewlines) }) ?? ""
        guard !text.isEmpty else { return [] }
        return [.sheet(input), .argument(text)]
    }
}
