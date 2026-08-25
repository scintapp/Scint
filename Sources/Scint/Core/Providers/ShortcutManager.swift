import KeyboardShortcuts
import SwiftUI


extension KeyboardShortcuts.Name {
    static let actions = Self("actions", default: .init(.p, modifiers: [.command]))
    static let assistant = Self("assistant", default: .init(.k, modifiers: [.command]))
    static let outline = Self("outline", default: .init(.o, modifiers: [.control]))
    static let search = Self("search", default: .init(.p, modifiers: [.command, .shift]))
    static let tasks = Self("tasks", default: .init(.t, modifiers: [.control]))
}

@MainActor final class ShortcutManager {
    static let shared = ShortcutManager()
    static let defaults = 2
    static let namespace = "scint.shortcuts"

    private var scint: ScintModel?
    private var registered = false
    private var names: [KeyboardShortcuts.Name] { [.actions, .assistant, .outline, .search, .tasks] }

    func register(scint: ScintModel) {
        self.scint = scint
        guard !registered else { return}
        registered = true

        reconcile()

        KeyboardShortcuts.onKeyDown(for: .actions) { Task { @MainActor in self.actions() } }
        KeyboardShortcuts.onKeyDown(for: .assistant) { Task { @MainActor in self.assistant() } }
        KeyboardShortcuts.onKeyDown(for: .outline) { Task { @MainActor in self.outline() } }
        KeyboardShortcuts.onKeyDown(for: .search) { Task { @MainActor in self.search() } }
        KeyboardShortcuts.onKeyDown(for: .tasks) { Task { @MainActor in self.tasks() } }
    }

    private func actions() { if let scint { scint.toggle(.actions, .studio) } }
    private func assistant() { if let scint { scint.toggle(.assistant, .studio) } }
    private func outline() { if let scint { scint.toggle(.outline, .editor) } }
    private func search() { if let scint { scint.toggle(.search, .studio) } }
    private func tasks() { if let scint { scint.toggle(.tasks, .studio) } }

    private func reconcile() {
        let key = "\(Self.namespace).defaults"

        guard UserDefaults.standard.integer(forKey: key) == Self.defaults else {
            KeyboardShortcuts.reset(names)
            UserDefaults.standard.set(Self.defaults, forKey: key)
            return
        }

        for name in names { sync(name) }
    }

    private func sync(_ name: KeyboardShortcuts.Name) {
        guard name.shortcut == nil else { return }
        KeyboardShortcuts.setShortcut(name.defaultShortcut, for: name)
    }
}
