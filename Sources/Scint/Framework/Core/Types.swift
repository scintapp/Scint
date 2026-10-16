import SwiftUI
import ScintRuntime


typealias Values = [AnyHashable: AnyHashable]

protocol HostSurface: CaseIterable, Identifiable {}
protocol ModelFrame: CaseIterable, Identifiable {}

@MainActor protocol Host: AnyObject {
    var state: StateContainer { get set }
    func controls(_ model: any Model) -> Controls
    func parameters(_ model: any Model) -> Params
}

extension Host {
    func controls(_ model: any Model) -> Controls { .init() }
    func parameters(_ model: any Model) -> Params { .init() }

    var bindable: Bindable<StateContainer> {
        @Bindable var state = self.state
        return $state
    }
}

protocol Frame: Host {
    associatedtype Surface
    func surface(_ model: AppModel) -> Surface
}

protocol Panel: Host {
    associatedtype Surface: View
    func surface(_ model: PanelModel) -> Surface
}

protocol Menu: Host {
    associatedtype Surface: View
    func surface(_ model: PanelModel) -> Surface
}

@MainActor protocol Mapper {
    static func controls(_ model: any Model) -> Controls
    static func parameters(_ model: any Model) -> Params
}

@MainActor protocol Model: AnyObject {
    var session: Session { get set }
    func focus(_ ref: Reference?)
    func select(_ ref: Reference, entry: UUID?, url: URL?)
    func open(_ ref: Reference)
}

@MainActor protocol Surface: View {
    var host: any Host { get set }
    var model: any Model { get set }
    func isExpanded(_ id: AnyHashable) -> Bool
    func setExpanded(_ id: AnyHashable)
    func isExpanded(_ id: AnyHashable, initially: Bool) -> Bool
    func setExpanded(_ id: AnyHashable, initially: Bool)
}

extension Surface {
    var render: (Self, Params, Controls) -> any View { Factory.build(_ :_ :_ :) }
    func isExpanded(_ id: AnyHashable) -> Bool { host.state.isExpanded(id) }
    func setExpanded(_ id: AnyHashable) { host.state.setExpanded(id) }
    func isExpanded(_ id: AnyHashable, initially: Bool) -> Bool { host.state.isExpanded(id, initially: initially) }
    func setExpanded(_ id: AnyHashable, initially: Bool) { host.state.setExpanded(id, initially: initially) }
}

extension Model {
    func focus(_ ref: Reference?) { session.focus(ref) }
    func select(_ ref: Reference, entry: UUID? = nil, url: URL? = nil) { session.select(ref, entry: entry, url: url) }
    func open(_ ref: Reference) { session.open(ref) }

    @discardableResult
    func resolve(_ ref: Reference) -> Context? { Runtime.shared.resolve(ref) }

    @discardableResult
    func compose(_ ref: Reference) -> Context? {
        Runtime.shared.compose(ref)
        return Runtime.shared.resolve(ref)
    }

    func cancel(_ ref: Reference) { Runtime.shared.cancel(ref) }

    func search(_ query: String, filters: [String] = [], limit: Int) -> SearchResults {
        Runtime.shared.search(query, filters: filters, limit: limit)
    }
}

struct AnySurface: Surface {
    var host: any Host
    var model: any Model
    var body: some View { render(self, host.parameters(model), host.controls(model)) }
    var render: (Self, Params, Controls) -> some View { Factory.build(_ :_ :_ :) }
    func isExpanded(_ id: AnyHashable) -> Bool { host.state.isExpanded(id) }
    func setExpanded(_ id: AnyHashable) { host.state.setExpanded(id) }
}

@Observable final class StateContainer {
    var presented: Bool
    var position: CGFloat
    var pinned: Bool = false
    var detail: Bool = false
    var query: String = ""
    var index: Int = 0
    var filter: String = ""
    var expanded: Set<AnyHashable>
    var collapsed: Set<Reference> = []
    var surface: String = ""
    var values: Values = [:]

    init(presented: Bool? = false, position: CGFloat? = 0, expanded: Set<AnyHashable>? = [], values: Values? = [:]) {
        self.presented = presented ?? false
        self.position = position ?? 0
        self.expanded = expanded ?? []
        self.values = values ?? [:]
    }

    var bindable: Bindable<StateContainer> {
        @Bindable var state = self
        return $state
    }

    func isExpanded(_ id: AnyHashable) -> Bool { expanded.contains(id) }

    func setExpanded(_ id: AnyHashable) {
        if expanded.contains(id) { expanded.remove(id) }
        else { expanded.insert(id) }
    }

    func isExpanded(_ id: AnyHashable, initially: Bool) -> Bool { self[id, as: Bool.self] ?? initially }

    func setExpanded(_ id: AnyHashable, initially: Bool) { self[id, as: Bool.self] = !isExpanded(id, initially: initially) }

    subscript<Value: Hashable>(_ key: AnyHashable, as type: Value.Type) -> Value? {
        get { values[key]?.base as? Value }
        set {
            if let newValue { values[key] = AnyHashable(newValue) }
            else { values[key] = nil }
        }
    }
}
