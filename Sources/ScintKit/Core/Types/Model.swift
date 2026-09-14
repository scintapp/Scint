import SwiftUI


enum ModelKey: String, Identifiable, CaseIterable {
    case studio, editor
    var id: String { self.model }
    var app: String { self.rawValue }
    var model: String { "scint" }
    var namespace: String { "\(app).\(model)" }
}

@MainActor protocol Model: AnyObject {
    var scint: ScintModel { get }
    var session: Session { get set }
    func focus(_ ref: Reference?)
    func select(_ ref: Reference, entry: UUID?, url: URL?)
    func open(_ ref: Reference)
}

extension Model {
    var roots: [Reference] {
        Runtime.shared.spaces.sorted {
            let order = $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name)
            return order == .orderedSame ? $0.id.uuidString < $1.id.uuidString : order == .orderedAscending
        }
    }

    func root(for space: Reference) -> Reference? {
        guard space.type is Space.Type, Space.with(space, { _ in true }) == true else { return nil }
        let first = session.navigation.spaces(to: space).first ?? space
        return Space.with(first, { $0.space ?? first })
    }

    func load(_ space: Reference) async {
        loadRoot(for: space)
    }

    private func loadRoot(for ref: Reference) {
        guard let root = root(for: ref), root != session.space else { return }
        session.load(root)
    }

    func focus(_ ref: Reference?) {
        session.focus(ref)
    }

    func select(_ ref: Reference, entry: UUID? = nil, url: URL? = nil) {
        loadRoot(for: ref)
        session.focus(ref)
        session.select(ref, entry: entry, url: url)
    }

    func open(_ ref: Reference) {
        loadRoot(for: ref)
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

    func artifacts(_ space: Reference) -> [Reference] {
        Space.with(space) { space in
            space.artifacts.filter { ref in
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
    var scint: ScintModel
    var content: any Panel
    var session: Session

    init(_ scint: ScintModel, session: Reference) {
        self.scint = scint
        self.content = AnyPanel()
        self.session = .init(session)
    }
}
