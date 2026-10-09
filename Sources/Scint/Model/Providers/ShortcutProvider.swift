import KeyboardShortcuts
import SwiftUI
import ScintRuntime


@MainActor final class ShortcutProvider {
    static let shared = ShortcutProvider()
    static let namespace = "scint.shortcuts"
    static let global = false

    struct Binding {
        let model: ModelKey
        let panel: PanelKey
        let shortcut: KeyboardShortcuts.Shortcut
        let name: KeyboardShortcuts.Name

        init(_ panel: PanelKey, _ source: ModelKey, _ key: KeyboardShortcuts.Key, _ modifiers: NSEvent.ModifierFlags) {
            let shortcut = KeyboardShortcuts.Shortcut(key, modifiers: modifiers)
            self.panel = panel
            self.model = source
            self.shortcut = shortcut
            self.name = .init(panel.rawValue, default: shortcut)
        }

        var signature: String { "\(panel.rawValue):\(shortcut.carbonKeyCode):\(shortcut.carbonModifiers)" }
    }

    private static let bindings: [Binding] = [
        .init(.actions, .app, .p, [.command, .shift]),
        .init(.search, .app, .k, [.command])
    ]

    private var model: ScintModel?
    private var registered = false
    private var observers: [NSObjectProtocol] = []

    func register(model: ScintModel) {
        self.model = model
        guard !registered else { return }
        registered = true

        prune()
        reconcile()

        for binding in Self.bindings {
            let (panel, source) = (binding.panel, binding.model)
            KeyboardShortcuts.onKeyDown(for: binding.name) { Task { @MainActor in self.toggle(panel, source) } }
        }

        guard !Self.global else { return }
        scope(NSApp.isActive)
        observers = [
            NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                Task { @MainActor in self.scope(true) }
            },
            NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { _ in
                Task { @MainActor in self.scope(false) }
            }
        ]
    }

    private func scope(_ active: Bool) {
        let names = Self.bindings.map(\.name)
        if active { KeyboardShortcuts.enable(names) }
        else { KeyboardShortcuts.disable(names) }
    }

    private func toggle(_ panel: PanelKey, _ source: ModelKey) { if let model { model.panel(panel, source) } }

    private func prune() {
        let prefix = "KeyboardShortcuts_"
        let live = Set(Self.bindings.map { prefix + $0.panel.rawValue })
        let store = UserDefaults.standard

        for key in store.dictionaryRepresentation().keys where key.hasPrefix(prefix) && !live.contains(key) {
            store.removeObject(forKey: key)
        }

        store.removeObject(forKey: "\(Self.namespace).defaults")
    }

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
