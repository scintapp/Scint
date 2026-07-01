import AppKit
import SwiftUI


@MainActor private struct EditorFocusKey: @MainActor EnvironmentKey {
    static let defaultValue = EditorFocusCoordinator()
}

@MainActor extension EnvironmentValues {
    var editorFocus: EditorFocusCoordinator {
        get { self[EditorFocusKey.self] }
        set { self[EditorFocusKey.self] = newValue }
    }
}

@MainActor final class EditorFocusCoordinator {
    private var views: [UUID: WeakBox] = [:]

    private final class WeakBox {
        weak var view: NSView?
        init(_ view: NSView) { self.view = view }
    }

    func register(_ view: NSView, for id: UUID) { views[id] = WeakBox(view) }

    func unregister(_ id: UUID) { views[id] = nil }

    func focus(_ targetID: UUID?, retry: Bool = true) {
        guard let targetID else { return }

        guard let view = views[targetID]?.view else {
            if retry {
                DispatchQueue.main.async { [weak self] in
                    self?.focus(targetID, retry: false)
                }
            }
            return
        }

        guard let window = view.window else {
            if retry {
                DispatchQueue.main.async { [weak self] in
                    self?.focus(targetID, retry: false)
                }
            }
            return
        }

        if window.firstResponder === view { return }
        window.makeFirstResponder(view)
    }
}
