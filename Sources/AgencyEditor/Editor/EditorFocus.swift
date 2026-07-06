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
            if retry { DispatchQueue.main.async { [weak self] in self?.focus(targetID, retry: false) } }
            return
        }

        guard let window = view.window else {
            if retry { DispatchQueue.main.async { [weak self] in self?.focus(targetID, retry: false) } }
            return
        }

        if window.firstResponder === view { return }
        window.makeFirstResponder(view)
    }
}

struct EntryResponder: NSViewRepresentable {
    let id: UUID
    let focus: EditorFocusCoordinator
    let onFocusGained: () -> Void
    let onCommand: (Selector) -> Bool

    func makeNSView(context: Context) -> EntryResponderView {
        let view = EntryResponderView()
        view.onFocusGained = onFocusGained
        view.onCommand = onCommand
        focus.register(view, for: id)
        return view
    }

    func updateNSView(_ view: EntryResponderView, context: Context) {
        view.onFocusGained = onFocusGained
        view.onCommand = onCommand
        focus.register(view, for: id)
    }
}

final class EntryResponderView: NSView {
    var onFocusGained: (() -> Void)?
    var onCommand: ((Selector) -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { onFocusGained?() }
        return became
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? self : hit
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        interpretKeyEvents([event])
    }

    override func doCommand(by selector: Selector) {
        if onCommand?(selector) == true { return }
        super.doCommand(by: selector)
    }

    override func moveUp(_ sender: Any?) { _ = onCommand?(#selector(NSResponder.moveUp(_:))) }
    override func moveDown(_ sender: Any?) { _ = onCommand?(#selector(NSResponder.moveDown(_:))) }
    override func insertNewline(_ sender: Any?) { _ = onCommand?(#selector(NSResponder.insertNewline(_:))) }
    override func deleteBackward(_ sender: Any?) { _ = onCommand?(#selector(NSResponder.deleteBackward(_:))) }
    override func cancelOperation(_ sender: Any?) { _ = onCommand?(#selector(NSResponder.cancelOperation(_:))) }
}
