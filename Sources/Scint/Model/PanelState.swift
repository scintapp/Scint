import Foundation
import SwiftUI


@Observable final class PanelState {
    var presented: Bool
    var position: CGFloat
    var pinned: Bool = false
    var detail: Bool = false
    var query: String = ""
    var index: Int = 0
    var filter: String = ""
    var expanded: Set<AnyHashable>
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
