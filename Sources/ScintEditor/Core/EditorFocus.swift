import AppKitimport SwiftUI


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
    private var views: [AnyHashable: WeakBox] = [:]
    private var targetID: AnyHashable?

    private final class WeakBox {
        weak var view: NSView?
        init(_ view: NSView) { self.view = view }
    }

    func register(_ view: NSView, for id: AnyHashable) { views[id] = WeakBox(view) }

    func unregister(_ id: AnyHashable) { views[id] = nil }

    func claim(_ id: AnyHashable) { targetID = id }

    func focus(_ targetID: AnyHashable?) {
        self.targetID = targetID
        for (id, box) in views where id != targetID {
            guard let view = box.view, view.window?.firstResponder === view else { continue }
            view.window?.makeFirstResponder(nil)
        }
        guard let targetID else { return }
        focus(targetID, attempts: 3)
    }

    private func focus(_ targetID: AnyHashable, attempts: Int) {
        guard self.targetID == targetID else { return }

        guard let view = views[targetID]?.view else {
            if attempts > 0 { DispatchQueue.main.async { [weak self] in self?.focus(targetID, attempts: attempts - 1) } }
            return
        }

        guard let window = view.window else {
            if attempts > 0 { DispatchQueue.main.async { [weak self] in self?.focus(targetID, attempts: attempts - 1) } }
            return
        }

        if window.firstResponder === view { return }
        window.makeFirstResponder(view)
    }
}

struct EntryResponder: NSViewRepresentable {
    let id: AnyHashable
    let focus: EditorFocusCoordinator
    let onFocusGained: () -> Void
    let onEdit: () -> Void
    let onCommand: (Selector) -> Bool

    func makeNSView(context: Context) -> EntryResponderView {
        let view = EntryResponderView()
        view.onFocusGained = {
            focus.claim(id)
            onFocusGained()
        }
        view.onEdit = onEdit
        view.onCommand = onCommand
        focus.register(view, for: id)
        return view
    }

    func updateNSView(_ view: EntryResponderView, context: Context) {
        view.onFocusGained = {
            focus.claim(id)
            onFocusGained()
        }
        view.onEdit = onEdit
        view.onCommand = onCommand
        focus.register(view, for: id)
    }
}

final class EntryResponderView: NSView {
    var onFocusGained: (() -> Void)?
    var onEdit: (() -> Void)?
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
        if event.charactersIgnoringModifiers == " ",
           event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            onEdit?()
            return
        }
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
