import SwiftUI
import ScintRuntime

protocol Mode: Identifiable, CaseIterable {}
enum ModelKey: String, Identifiable, CaseIterable {
    case studio, editor
    var id: String { self.rawValue }
}

@MainActor protocol Model: AnyObject {
    var session: Session { get set }
    func focus(_ ref: Reference?)
    func select(_ ref: Reference, entry: UUID?, url: URL?)
    func open(_ ref: Reference)
}

extension Model {
    func focus(_ ref: Reference?) {
        session.focus(ref)
    }

    func select(_ ref: Reference, entry: UUID? = nil, url: URL? = nil) {
        session.select(ref, entry: entry, url: url)
    }

    func open(_ ref: Reference) {
        session.open(ref)
    }

    func search(_ query: String, filters: [String] = [], limit: Int) -> SearchResults {
        Runtime.shared.search(query, filters: filters, limit: limit)
    }

    func compose(_ ref: Reference) -> Composition? { Runtime.shared.compose(ref) }

    @discardableResult
    func start(_ ref: Reference) -> Composition? { Runtime.shared.start(ref) }

    @discardableResult
    func stop(_ ref: Reference) -> Composition? { Runtime.shared.stop(ref) }
}
