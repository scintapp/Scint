import SwiftUI


typealias Values = [AnyHashable: AnyHashable]
private let anyRef = Reference(Workspace.self)

enum Layout: CaseIterable { case grid, group, list, table }
enum Nesting: String, CaseIterable { case recursive, single, flat }

protocol PanelSurface: CaseIterable, Identifiable {}

@MainActor protocol Mapper {
    static func controls(_ model: any Model) -> Controls
    static func parameters(_ model: any Model) -> Params
}

@MainActor protocol Panel: AnyObject {
    associatedtype Surface
    associatedtype PanelSurface
    var state: PanelState { get set }
    var surface: PanelSurface { get set }
    func controls(_ model: any Model) -> Controls
    func parameters(_ model: any Model) -> Params
    func surface(_ model: any Model) -> Surface
}

@MainActor protocol Surface: View {
    var panel: any Panel { get set }
    var model: any Model { get set }
    func isExpanded(_ id: AnyHashable) -> Bool
    func setExpanded(_ id: AnyHashable)
}

@MainActor protocol Model: AnyObject {
    var session: Session { get set }
    func focus(_ ref: Reference?)
    func select(_ ref: Reference, entry: UUID?, url: URL?)
    func open(_ ref: Reference)
}

extension Mapper {
    static func controls(_ model: any Model) -> Controls { .init() }
    static func parameters(_ model: any Model) -> Params { .init() }
}

extension Panel {
    func controls(_ model: any Model) -> Controls { .init() }
    func parameters(_ model: any Model) -> Params { .init() }
}

extension Surface {
    var render: (Self, Params, Controls) -> some View { Factory.build(_ :_ :_ :) }
    func isExpanded(_ id: AnyHashable) -> Bool { panel.state.isExpanded(id) }
    func setExpanded(_ id: AnyHashable) { panel.state.setExpanded(id) }
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

    func start(_ ref: Reference) -> Composition? {
        let input = Space.with(ref, { $0.input }).flatMap { $0 } ?? Workspace.with(ref, { $0.input }).flatMap { $0 }
        guard let input, let prompt = Material.with(input, { $0.rendered }), !prompt.isEmpty else { return nil }
        var config: Config = ["prompt": .string(prompt), "session": session.rendered]
        if let transcript = session.transcript { config["transcript"] = .reference(transcript) }
        guard let composition = Runtime.shared.start(ref, config: config) else { return nil }
        Material.update(input) { $0.clear() }
        return composition
    }

    func search(_ query: String, limit: Int) -> SearchResults { Runtime.shared.search(query, limit: limit) }

    func artifacts(_ workspace: Reference) -> [Reference] {
        Workspace.with(workspace) { workspace in
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
    var panel: any Panel
    var session: Session

    init(_ workspace: Reference) {
        self.panel = AnyPanel()
        self.session = .init(anyRef)
    }
}

final class AnyPanel: Panel {
    var state: PanelState
    var surface: PanelSurface = .any

    enum PanelSurface: String, CaseIterable, Identifiable {
        case any
        var id: String { rawValue }
        var image: String { "text.rectangle" }
    }

    init(state: PanelState = .init()) { self.state = state }
    func controls(_ model: any Model) -> Controls { .init() }
    func parameters(_ model: any Model) -> Params { .init() }
    func surface(_ model: any Model) -> some View { EmptyView() }
}

struct AnySurface: Surface {
    var panel: any Panel
    var model: any Model
    var body: some View { render(self, panel.parameters(model), panel.controls(model)) }
    var render: (Self, Params, Controls) -> some View { Factory.build(_ :_ :_ :) }
    func isExpanded(_ id: AnyHashable) -> Bool { panel.state.isExpanded(id) }
    func setExpanded(_ id: AnyHashable) { panel.state.setExpanded(id) }
}
