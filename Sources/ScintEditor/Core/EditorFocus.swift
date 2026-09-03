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

        // Only an explicitly nil target blanks the responder. Resigning every non-target view
        // first left a window with no first responder whenever the target's view wasn't mounted
        // yet — and `makeFirstResponder` already resigns whoever held it.
        guard let targetID else {
            for box in views.values {
                guard let view = box.view, view.window?.firstResponder === view else { continue }
                view.window?.makeFirstResponder(nil)
            }
            return
        }

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
    let onEdit: (CGRect) -> Void
    let onCommand: (Selector) -> Bool

    func makeNSView(context: Self.Context) -> EntryResponderView {
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

    func updateNSView(_ view: EntryResponderView, context: Self.Context) {
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
    var onEdit: ((CGRect) -> Void)?
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

    /// Where this block sits on screen, for anchoring the form that edits it.
    var screenFrame: CGRect {
        guard let window else { return .zero }
        return window.convertToScreen(convert(bounds, to: nil))
    }

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " ",
           event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            onEdit?(screenFrame)
            return
        }
        interpretKeyEvents([event])
    }

    /// The single command path. The five per-selector overrides that used to sit alongside this
    /// were all reachable through here anyway, so they only ever ran the same handler twice.
    override func doCommand(by selector: Selector) {
        if onCommand?(selector) == true { return }
        super.doCommand(by: selector)
    }

    /// Cmd-A reaches a card the same way it reaches the text view: as a responder-chain action,
    /// never through `doCommand(by:)`.
    override func selectAll(_ sender: Any?) {
        if onCommand?(#selector(NSResponder.selectAll(_:))) == true { return }
        super.selectAll(sender)
    }
}
