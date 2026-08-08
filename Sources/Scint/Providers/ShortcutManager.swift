import KeyboardShortcuts
import SwiftUI


extension KeyboardShortcuts.Name {
    static let actions = Self("actions", default: .init(.p, modifiers: [.command, .shift]))
    static let assistant = Self("assistant", default: .init(.k, modifiers: [.command, .shift]))
    static let outline = Self("outline", default: .init(.o, modifiers: [.command, .shift]))
    static let search = Self("search", default: .init(.f, modifiers: [.command, .shift]))
    static let tasks = Self("tasks", default: .init(.t, modifiers: [.command]))
}

@MainActor final class ShortcutManager {
    static let shared = ShortcutManager()
    private var scint: ScintModel?

    func register(scint: ScintModel) {
        self.scint = scint
        sync(.actions)
        sync(.assistant)
        sync(.outline)
        sync(.search)
        sync(.tasks)

        KeyboardShortcuts.onKeyDown(for: .actions) { Task { @MainActor in self.actions() } }
        KeyboardShortcuts.onKeyDown(for: .assistant) { Task { @MainActor in self.assistant() } }
        KeyboardShortcuts.onKeyDown(for: .outline) { Task { @MainActor in self.outline() } }
        KeyboardShortcuts.onKeyDown(for: .search) { Task { @MainActor in self.search() } }
        KeyboardShortcuts.onKeyDown(for: .tasks) { Task { @MainActor in self.tasks() } }
    }

    private func actions() { if let scint { return scint.toggleActions() } }
    private func assistant() { if let scint { return scint.toggleAssistant() } }
    private func outline() { if let scint { return scint.toggleOutline() } }
    private func search() { if let scint { return scint.toggleSearch() } }
    private func tasks() { if let scint { return scint.toggleTasks() } }

    private func sync(_ name: KeyboardShortcuts.Name) {
        guard name.shortcut == nil else { return }
        KeyboardShortcuts.setShortcut(name.defaultShortcut, for: name)
    }
}
