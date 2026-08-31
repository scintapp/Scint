import KeyboardShortcuts
import SwiftUI


@MainActor final class ShortcutManager {
    static let shared = ShortcutManager()
    static let namespace = "scint.shortcuts"

    struct Binding {
        let panel: PanelKey
        let source: ModelKey
        let shortcut: KeyboardShortcuts.Shortcut
        let name: KeyboardShortcuts.Name

        init(_ panel: PanelKey, _ source: ModelKey, _ key: KeyboardShortcuts.Key, _ modifiers: NSEvent.ModifierFlags) {
            let shortcut = KeyboardShortcuts.Shortcut(key, modifiers: modifiers)
            self.panel = panel
            self.source = source
            self.shortcut = shortcut
            self.name = .init(panel.rawValue, default: shortcut)
        }

        var signature: String { "\(panel.rawValue):\(shortcut.carbonKeyCode):\(shortcut.carbonModifiers)" }
    }

    private static let bindings: [Binding] = [
        .init(.actions, .studio, .k, [.command]),
        .init(.search, .studio, .p, [.command, .shift]),
        .init(.assistant, .studio, .s, [.control]),
        .init(.outline, .editor, .o, [.control]),
        .init(.tasks, .studio, .t, [.control]),
    ]

    private var scint: ScintModel?
    private var registered = false

    func register(scint: ScintModel) {
        self.scint = scint
        guard !registered else { return }
        registered = true

        validate()
        prune()
        reconcile()

        for binding in Self.bindings {
            let (panel, source) = (binding.panel, binding.source)
            KeyboardShortcuts.onKeyDown(for: binding.name) { Task { @MainActor in self.toggle(panel, source) } }
        }
    }

    private func toggle(_ panel: PanelKey, _ source: ModelKey) { if let scint { scint.toggle(panel, source) } }

    private func validate() {
        let panels = Self.bindings.map(\.panel)
        assert(Set(panels).count == panels.count, "duplicate panel in shortcut bindings: \(panels)")

        let shortcuts = Self.bindings.map(\.shortcut)
        assert(Set(shortcuts).count == shortcuts.count, "conflicting default shortcuts: \(shortcuts)")
    }

    /// `KeyboardShortcuts` keys its storage by name alone, so renamed or retired bindings linger forever.
    private func prune() {
        let prefix = "KeyboardShortcuts_"
        let live = Set(Self.bindings.map { prefix + $0.panel.rawValue })
        let store = UserDefaults.standard

        for key in store.dictionaryRepresentation().keys where key.hasPrefix(prefix) && !live.contains(key) {
            store.removeObject(forKey: key)
        }

        store.removeObject(forKey: "\(Self.namespace).defaults")
    }

    /// Seeded defaults only apply to keys that are absent, so an edited default needs an explicit reset.
    private func reconcile() {
        let key = "\(Self.namespace).signature"
        let signature = Self.bindings.map(\.signature).sorted().joined(separator: ",")

        guard UserDefaults.standard.string(forKey: key) == signature else {
            KeyboardShortcuts.reset(Self.bindings.map(\.name))
            UserDefaults.standard.set(signature, forKey: key)
            return
        }

        for binding in Self.bindings where binding.name.shortcut == nil {
            KeyboardShortcuts.setShortcut(binding.shortcut, for: binding.name)
        }
    }
}
