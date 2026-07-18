import Foundation
import SwiftUI

@Observable final class StateContainer {
    var presented: Bool = false
    var position: CGFloat = 0
    var filter: String = ""
    var expanded: Set<AnyHashable> = []
    var values: [AnyHashable: AnyHashable] = [:]

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
