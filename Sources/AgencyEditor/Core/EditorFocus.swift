import AppKit
import SwiftUI

private struct EditorFocusKey: @MainActor EnvironmentKey {
    @MainActor static let defaultValue = EditorFocusCoordinator()
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
        guard let targetID, let view = views[targetID]?.view else { return }

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
