import KeyboardShortcuts
import SwiftUI


extension KeyboardShortcuts.Name {
    static let toggleAperture = Self("toggleAperture", default: .init(.a, modifiers: [.command, .shift]))
//    static let toggleComposer = Self("toggleComposer", default: .init(.k, modifiers: [.command]))
    static let toggleProcesses = Self("toggleProcesses", default: .init(.p, modifiers: [.command, .shift]))
}

@MainActor final class ShortcutManager {
    weak var agency: AgencyModel?
    static let shared = ShortcutManager()
    private var registered = false

    func register(agency: AgencyModel) {
        self.agency = agency
        sync(.toggleAperture)
//        sync(.toggleComposer)
        sync(.toggleProcesses)

        guard !registered else { return }
        registered = true
        KeyboardShortcuts.onKeyDown(for: .toggleAperture) { self.agency?.toggleAperture() }
//        KeyboardShortcuts.onKeyDown(for: .toggleComposer) { self.agency?.toggleComposer() }
        KeyboardShortcuts.onKeyDown(for: .toggleProcesses) { self.agency?.toggleProcesses() }

    }

    private func sync(_ name: KeyboardShortcuts.Name) {
        guard name.shortcut != name.defaultShortcut else { return }
        KeyboardShortcuts.setShortcut(name.defaultShortcut, for: name)
    }
}

