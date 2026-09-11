import SwiftUI


private let anyRef = Reference(Space.self)

enum ModelKey: String, Identifiable, CaseIterable {
    case assistant, editor, studio
    var id: String { self.model }
    var app: String { self.rawValue }
    var model: String { "scint" }
    var namespace: String { "\(app).\(model)" }
}

@MainActor protocol Model: AnyObject {
    associatedtype Panel
    var content: Panel { get }
    var session: Session { get set }
    func focus(_ ref: Reference?)
    func select(_ ref: Reference, entry: UUID?, url: URL?)
    func open(_ ref: Reference)
}

extension Model {
    func load(_ workspace: Reference) async {
        session.load(workspace)
    }

    func focus(_ ref: Reference?) {
        session.focus(ref)
    }

    func select(_ ref: Reference, entry: UUID? = nil, url: URL? = nil) {
        session.focus(ref)
        session.select(ref, entry: entry, url: url)
    }

    func open(_ ref: Reference) {
        session.focus(ref)
        session.open(ref)
    }

    func compose(_ ref: Reference) -> Composition? { Runtime.shared.compose(ref) }

    @discardableResult
    func start(_ ref: Reference) -> Composition? { Runtime.shared.start(ref) }

    @discardableResult
    func stop(_ ref: Reference) -> Composition? { Runtime.shared.stop(ref) }

    func search(_ query: String, filters: [String] = [], limit: Int) -> SearchResults {
        Runtime.shared.search(query, filters: filters, limit: limit)
    }

    func artifacts(_ workspace: Reference) -> [Reference] {
        Space.with(workspace) { workspace in
            workspace.artifacts.filter { ref in
                Artifact.with(ref) {
                    switch $0.handler {
                        case .directory, .file: true
                        default: false
                    }
                } == true
            }
        } ?? []
    }
}

final class AnyModel: Model {
    var content: any Panel
    var session: Session

    init(_ workspace: Reference) {
        self.content = AnyPanel()
        self.session = .init(anyRef)
    }
}
