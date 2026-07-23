import Foundation
import SwiftUI

@Observable final class StateContainer {
    var presented: Bool
    var position: CGFloat
    var filter: String
    var expanded: Set<AnyHashable>
    var values: [AnyHashable: AnyHashable]

    init(
        presented: Bool? = false,
        position: CGFloat? = 0,
        filter: String? = "",
        expanded: Set<AnyHashable>? = [],
        values: [AnyHashable : AnyHashable]? = [:]
    ) {
        self.presented = presented ?? false
        self.position = position ?? 0
        self.filter = filter ?? ""
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
