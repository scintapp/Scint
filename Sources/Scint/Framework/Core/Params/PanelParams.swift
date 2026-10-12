import SwiftUI
import UniformTypeIdentifiers
import ScintRuntime


struct PanelDismissal: OptionSet, Hashable {
    let rawValue: Int
    static let escape = Self(rawValue: 1 << 0)
    static let outsideClick = Self(rawValue: 1 << 1)
    static let resignKey = Self(rawValue: 1 << 2)
}

struct PanelParams: Hashable {
    var size: CGSize
    var placement: Placement = .centered
    var dismissal: PanelDismissal = [.escape, .outsideClick]
    var focused = true

    enum Placement: Hashable {
        case centered
        case anchored(CGRect)
    }
}
