import AgencyRuntime
import Foundation
import SwiftUI


@Observable @MainActor final class AgencyModel {
    var app: AppModel
    var files: FileProvider
    var session: SessionModel

    init(_ workspace: Reference) {
        self.app = .init()
        self.files = .init(workspace)
        self.session = .init(workspace)
    }

    func load() async {
        await load(Runtime.shared.workspace)
        await SampleData.load()
        do { try await Runtime.shared.save() }
        catch { print(error) }
    }

    func load(_ workspace: Reference) async {
        session.load(workspace)
        await files.load(runtime: Runtime.shared)
    }

    var origin: Reference { session.selected.space ?? session.workspace }

    var composable: Bool {
        Space.with(origin, { $0.composable }) ?? Workspace.with(origin, { $0.composable }) ?? false
    }

    var input: Reference? {
        let closure = Space.with(origin, { $0.closure }) ?? Workspace.with(origin, { $0.closure })
        return closure.flatMap { Closure.with($0, { $0.input }) }
    }

    @discardableResult func compose() -> AgencyRuntime.Composition? {
        guard let composition = Runtime.shared.trigger(origin) else { return nil }
        if let transcript = composition.intentTranscript { open(transcript) }
        return composition
    }

    func context(_ space: Reference) -> AgencyRuntime.Composition? {
        guard let composition = Runtime.shared.context(for: space) else { return nil }
        return composition
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

    func handle(_ url: URL) -> Runtime.Callback? {
        do {
            let callback = try Runtime.shared.handle(url)
            switch callback {
                case .open(let ref): open(ref)
                case .dispatch(_, _, let error):
                    if let error { print(error) }
                case .search(let results):
                    app.actions.query = results.query
                    app.panels.show(app.actions, in: self)
            }
            return callback
        } catch {
            print(error)
            return nil
        }
    }
}
