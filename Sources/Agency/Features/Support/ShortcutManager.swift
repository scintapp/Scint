import KeyboardShortcuts
import SwiftUI


extension KeyboardShortcuts.Name {
    static let toggleCompose = Self("toggleCompose", default: .init(.l, modifiers: [.command, .shift]))
    static let toggleSearch = Self("toggleSearch", default: .init(.p, modifiers: [.command, .shift]))
    static let toggleActivity = Self("toggleActivity", default: .init(.k, modifiers: [.command]))
}

@MainActor final class ShortcutManager {
    weak var agency: AgencyModel?
    static let shared = ShortcutManager()

    func register(agency: AgencyModel) {
        self.agency = agency
        KeyboardShortcuts.onKeyDown(for: .toggleCompose) { self.agency?.toggleCompose() }
        KeyboardShortcuts.onKeyDown(for: .toggleActivity) { self.agency?.toggleActivity() }
//        KeyboardShortcuts.onKeyDown(for: .toggleSearch) { self.agency?.toggleSearch() }
    }
}
