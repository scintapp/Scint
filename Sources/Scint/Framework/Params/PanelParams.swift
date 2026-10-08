import SwiftUI
import UniformTypeIdentifiers
import ScintRuntime


struct PanelParams: Hashable, Identifiable {
    var key: PanelKey
    var sizing: Sizing
    var dismissal: PanelDismissal = [.escape, .outsideClick]
    var movable = true
    var resizable = false
    var pinnable = false

    var id: PanelKey { key }

    struct Sizing: Hashable {
        var size: CGSize
        var min: CGSize?
        var max: CGSize?
    }
}
