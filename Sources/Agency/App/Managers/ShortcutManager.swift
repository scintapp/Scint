import KeyboardShortcuts
import SwiftUI


extension KeyboardShortcuts.Name {
//    static let toggleAperture = Self("toggleAperture", default: .init(.a, modifiers: [.command, .shift]))
}

@MainActor final class ShortcutManager {
    weak var agency: AgencyModel?
    static let shared = ShortcutManager()
    private var registered = false

    func register(agency: AgencyModel) {
        self.agency = agency
//        sync(.toggleAperture)
        guard !registered else { return }
        registered = true
//        KeyboardShortcuts.onKeyDown(for: .toggleAperture) { self.agency?.toggleAperture() }

    }

    private func sync(_ name: KeyboardShortcuts.Name) {
        guard name.shortcut != name.defaultShortcut else { return }
        KeyboardShortcuts.setShortcut(name.defaultShortcut, for: name)
    }
}

