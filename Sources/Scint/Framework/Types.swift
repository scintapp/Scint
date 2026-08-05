import SwiftUI


typealias Values = [AnyHashable: AnyHashable]

enum Layout: CaseIterable { case grid, group, list, table }
enum Nesting: String, CaseIterable { case recursive, single, flat }

@MainActor protocol Model: AnyObject {
    var session: Session { get set }
    var files: FileProvider { get set }
    func focus(_ ref: Reference?)
    func select(_ ref: Reference)
    func open(_ ref: Reference)
}

@MainActor protocol Mapper {
    static func controls(_ model: any Model) -> Controls
    static func parameters(_ model: any Model) -> Params
    static func item(from result: SearchResult) -> ItemParams
}

@MainActor protocol Panel: AnyObject {
    associatedtype Surface
    var state: StateContainer { get set }
    func controls(_ model: any Model) -> Controls
    func parameters(_ model: any Model) -> Params
    func panel(_ model: any Model) -> Surface
}

@MainActor protocol Surface: View {
    var panel: any Panel { get set }
    var model: any Model { get }
    func isExpanded(_ id: AnyHashable) -> Bool
    func setExpanded(_ id: AnyHashable)
}

extension Model {
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

    func load(_ workspace: Reference) async {
        session.load(workspace)
    }

    func compose(_ ref: Reference) -> Composition? {
        let input = Space.with(ref, { $0.input }).flatMap { $0 } ?? Workspace.with(ref, { $0.input }).flatMap { $0 }
        guard let input, Sheet.with(input, { !$0.blocks.isEmpty }) == true else { return nil }
        Sheet.update(input) { $0.insert(.text(.init(), session.rendered.property.stringRepresentation), at: nil) }
        if ref.type is Workspace.Type { Workspace.update(ref) { $0.input = input } }
        else { Space.update(ref) { $0.input = input } }
        guard let composition = Runtime.shared.eval(ref) else { return nil }
        if let transcript = composition.intentTranscript { open(transcript) }
        return composition
    }

    func search(_ query: String, limit: Int) -> SearchResults { Runtime.shared.search(query, limit: limit) }
}

extension Mapper {
    static func controls(_ model: any Model) -> Controls { .init() }
    static func parameters(_ model: any Model) -> Params { .init() }
    static func item(from result: SearchResult) -> ItemParams {
        .init(
            ref: result.ref,
            name: result.name,
            image: Iconography.icon(for: result.ref).symbol,
            description: result.description
        )
    }
}

extension Panel {
    func controls(_ model: any Model) -> Controls { .init() }
    func parameters(_ model: any Model) -> Params { .init() }
}

extension Surface {
    var render: (Self, Params, Controls) -> some View { Builder.build(_ :_ :_ :) }
    func isExpanded(_ id: AnyHashable) -> Bool { panel.state.isExpanded(id) }
    func setExpanded(_ id: AnyHashable) { panel.state.setExpanded(id) }
}

struct AnySurface: Surface {
    var panel: any Panel
    let model: any Model
    var render: (Self, Params, Controls) -> some View { Builder.build(_ :_ :_ :) }
    var body: some View { render(self, panel.parameters(model), panel.controls(model)) }
    func isExpanded(_ id: AnyHashable) -> Bool { panel.state.isExpanded(id) }
    func setExpanded(_ id: AnyHashable) { panel.state.setExpanded(id) }
}

@Observable final class StateContainer {
    var presented: Bool
    var position: CGFloat
    var filter: String = ""
    var query: String = ""
    var expanded: Set<AnyHashable>
    var values: Values

    init(presented: Bool? = false, position: CGFloat? = 0, expanded: Set<AnyHashable>? = [], values: Values? = [:]) {
        self.presented = presented ?? false
        self.position = position ?? 0
        self.expanded = expanded ?? []
        self.values = values ?? [:]
    }

    func isExpanded(_ id: AnyHashable) -> Bool { expanded.contains(id) }

    func setExpanded(_ id: AnyHashable) {
        if expanded.contains(id) { expanded.remove(id) }
        else { expanded.insert(id) }
    }

    subscript<Value: Hashable>(_ key: AnyHashable, as type: Value.Type) -> Value? {
        get { values[key]?.base as? Value }
        set {
            if let newValue { values[key] = AnyHashable(newValue) }
            else { values[key] = nil }
        }
    }
}
