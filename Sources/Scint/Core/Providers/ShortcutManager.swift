import KeyboardShortcuts
import SwiftUI


extension KeyboardShortcuts.Name {
    static let palette = Self("palette", default: .init(.k, modifiers: [.command]))
    static let togglePanel = Self("togglePanel", default: .init(.a, modifiers: [.command, .shift]))
}

@MainActor final class ShortcutManager {
    static let shared = ShortcutManager()
    private var scint: ScintModel?

    func register(scint: ScintModel) {
        self.scint = scint
        sync(.palette)
        sync(.togglePanel)

        KeyboardShortcuts.onKeyDown(for: .palette) {
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
        guard let scint else { return }
        scint.togglePalette()
    }

    private func sync(_ name: KeyboardShortcuts.Name) {
        guard name.shortcut == nil else { return }
        KeyboardShortcuts.setShortcut(name.defaultShortcut, for: name)
    }
}
