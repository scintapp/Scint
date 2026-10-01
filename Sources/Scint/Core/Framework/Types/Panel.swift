import SwiftUI
import ScintRuntime


typealias Values = [AnyHashable: AnyHashable]

protocol PanelSurface: CaseIterable, Identifiable {}

@MainActor protocol Panel: AnyObject {
    associatedtype Surface
    associatedtype PanelSurface
    var state: PanelState { get set }
    var surface: PanelSurface { get set }
    func controls(_ model: any Model) -> Controls
    func parameters(_ model: any Model) -> Params
    func surface(_ model: any Model) -> Surface
}

extension Panel {
    func controls(_ model: any Model) -> Controls { .init() }
    func parameters(_ model: any Model) -> Params { .init() }

    var bindable: Bindable<PanelState> {
        @Bindable var state = self.state
        return $state
    }
}

@Observable final class PanelState {
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

    var bindable: Bindable<PanelState> {
        @Bindable var state = self
        return $state
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
    func surface(_ model: any Model) -> any View { EmptyView() }
}
