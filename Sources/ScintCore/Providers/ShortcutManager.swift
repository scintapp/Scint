import KeyboardShortcutsimport SwiftUI


extension KeyboardShortcuts.Name {
    static let actions = Self("actions", default: .init(.k, modifiers: [.command]))
    static let togglePanel = Self("togglePanel", default: .init(.a, modifiers: [.command, .shift]))
}

@MainActor final class ShortcutManager {
    static let shared = ShortcutManager()
    private var Scint: ScintModel?

    func register(Scint: ScintModel) {
        self.Scint = Scint
        sync(.actions)
        sync(.togglePanel)

        KeyboardShortcuts.onKeyDown(for: .actions) {
            Task { @MainActor in
                self.togglePanel()
            }
        }

        KeyboardShortcuts.onKeyDown(for: .togglePanel) {
            Task { @MainActor in
                self.togglePanel()
            }
        }
    }

    private func togglePanel() {
        guard let Scint else { return }
        Scint.toggleActions()
    }

    private func sync(_ name: KeyboardShortcuts.Name) {
        guard name.shortcut == nil else { return }
        KeyboardShortcuts.setShortcut(name.defaultShortcut, for: name)
    }
}
