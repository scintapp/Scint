import KeyboardShortcuts
import SwiftUI


extension KeyboardShortcuts.Name {
    static let actions = Self("actions", default: .init(.k, modifiers: [.command]))
    static let togglePanel = Self("togglePanel", default: .init(.a, modifiers: [.command, .shift]))
}

@MainActor final class ShortcutManager {
    static let shared = ShortcutManager()
    private var agency: AgencyModel?

    func register(agency: AgencyModel) {
        self.agency = agency
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
        guard let agency else { return }
        agency.panels.togglePanel(agency, content: agency.studio.actions.view(agency))
    }

    private func sync(_ name: KeyboardShortcuts.Name) {
        guard name.shortcut == nil else { return }
        KeyboardShortcuts.setShortcut(name.defaultShortcut, for: name)
    }
}
