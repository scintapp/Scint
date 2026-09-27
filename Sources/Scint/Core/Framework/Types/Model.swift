import SwiftUI
import ScintRuntime


protocol Mode: Identifiable, CaseIterable {}

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

    func compose(_ ref: Reference) -> Context? { Runtime.shared.compose(ref) }

    @discardableResult
    func start(_ ref: Reference) -> Context? { Runtime.shared.start(ref) }

    @discardableResult
    func observe(_ ref: Reference) -> Context? { Runtime.shared.observe(ref) }

    @discardableResult
    func stop(_ ref: Reference) -> Context? { Runtime.shared.stop(ref) }
}

protocol Selecting: Codable, Equatable, Sendable {
    var root: Reference? { get set }
    func selected(_ ref: Reference) -> Bool
    func selected(_ ref: Reference, _ entry: UUID?) -> Bool
    func selected(_ ref: Reference, _ url: URL?) -> Bool
    func selecting(_ ref: Reference, _ entry: UUID?, _ url: URL?) -> Self
}
