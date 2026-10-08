import AppKit
import SwiftUI
import ScintRuntime
import ScintComponents


final class MenuFilterTextField: NSTextField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow(); window?.makeFirstResponder(self)
    }
}

struct MenuFilterField: NSViewRepresentable {
    @Binding var text: String
    let onCommand: (Selector) -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Self.Context) -> NSTextField {
        let field = MenuFilterTextField(string: text)
        field.delegate = context.coordinator
        field.placeholderString = "Filter"
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        field.textColor = NSColor(Style.Foreground.secondary)
        field.usesSingleLineMode = true
        return field
    }

    func updateNSView(_ field: NSTextField, context: Self.Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
        context.coordinator.focus(field)
    }

    @MainActor final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MenuFilterField

        init(_ parent: MenuFilterField) { self.parent = parent }

        func focus(_ field: NSTextField) {
            guard field.currentEditor() == nil, let window = field.window else { return }
            window.makeFirstResponder(field)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            parent.onCommand(selector)
        }
    }
}

struct MenuFilter: View {
    @Binding var text: String
    let onMoveSelection: (Int) -> Void
    let onCommit: () -> Void
    let onCancel: () -> Void

    func handle(_ selector: Selector) -> Bool {
        switch NSStringFromSelector(selector) {
            case "moveDown:", "insertTab:": onMoveSelection(1)
            case "moveUp:", "insertBacktab:": onMoveSelection(-1)
            case "insertNewline:": onCommit()
            case "cancelOperation:": onCancel()
            case "deleteBackward:" where text.isEmpty: onCancel()
            default: return false
        }
        return true
    }

    var body: some View {
        HStack(alignment: .center) {
            MenuFilterField(text: $text, onCommand: handle)
        }
    }
}
