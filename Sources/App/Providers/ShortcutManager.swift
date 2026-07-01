import KeyboardShortcuts
import SwiftUI


extension KeyboardShortcuts.Name {
    static let actions = Self("actionsPanel", default: .init(.k, modifiers: [.command]))
}

@MainActor final class ShortcutManager {
    weak var agency: AgencyModel?
    static let shared = ShortcutManager()
    private var registered = false

    func register(agency: AgencyModel) {
        self.agency = agency
        sync(.actions)
        guard !registered else { return }
        registered = true
        KeyboardShortcuts.onKeyDown(for: .actions) { self.agency?.actions() }

    }

    private func sync(_ name: KeyboardShortcuts.Name) {
        guard name.shortcut != name.defaultShortcut else { return }
        KeyboardShortcuts.setShortcut(name.defaultShortcut, for: name)
    }
}

