import AppKit
import SwiftUI


struct EditorTaskBlock: View {
    @Environment(EditorModel.self) private var editor
    let segment: EditorSegment.TaskSegment

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack {
                Button(action: toggle) {
                    Image(systemName: segment.complete ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(
                            segment.complete ? Design.Tint.tasks : Color.primary.opacity(0.45)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: 22, height: 22)
                Spacer(minLength: 0)
            }
            .padding(.top, 6)

            TaskTitleField(
                segmentID: segment.id,
                text: segment.title,
                complete: segment.complete,
                isFocused: editor.focusedSegmentID == segment.id,
                onChange: { newValue in editor.updateTask(segmentID: segment.id, title: newValue) },
                onFocusGained: { editor.focusTask(segmentID: segment.id) },
                onSubmit: { editor.taskReturn(from: segment.id) },
                onBackspaceEmpty: { editor.taskDeleteBackward(segmentID: segment.id) },
                onToggle: toggle
            )
            .padding(.leading, 4)
            .padding(.vertical, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary).opacity(0.025)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary, lineWidth: 0.5).opacity(0.08)
                )
        )
    }

    private func toggle() {
        editor.updateTask(segmentID: segment.id, complete: !segment.complete)
    }
}

private struct TaskTitleField: NSViewRepresentable {
    let segmentID: UUID
    let text: String
    let complete: Bool
    let isFocused: Bool
    let onChange: (String) -> Void
    let onFocusGained: () -> Void
    let onSubmit: () -> Void
    let onBackspaceEmpty: () -> Bool
    let onToggle: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> TaskNSTextField {
        let field = TaskNSTextField()
        field.delegate = context.coordinator
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 15, weight: .light)
        field.placeholderString = "Task"
        field.bezelStyle = .roundedBezel
        field.isBezeled = false
        field.cell?.usesSingleLineMode = false
        field.cell?.wraps = true
        field.cell?.isScrollable = false
        field.lineBreakMode = .byWordWrapping
        field.stringValue = text
        field.coordinator = context.coordinator
        applyStyle(to: field)
        return field
    }

    func updateNSView(_ view: TaskNSTextField, context: Context) {
        context.coordinator.parent = self
        if view.stringValue != text { view.stringValue = text }
        applyStyle(to: view)
        DispatchQueue.main.async { syncFocus(view: view) }
    }

    private func applyStyle(to view: TaskNSTextField) {
        let color: NSColor = complete
            ? NSColor.labelColor.withAlphaComponent(0.45)
            : NSColor.labelColor
        let attrs: [NSAttributedString.Key: Any] = {
            var a: [NSAttributedString.Key: Any] = [
                .foregroundColor: color,
                .font: view.font ?? NSFont.systemFont(ofSize: 15, weight: .light),
            ]
            if complete {
                a[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                a[.strikethroughColor] = color
            }
            return a
        }()
        view.attributedStringValue = NSAttributedString(string: view.stringValue, attributes: attrs)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        if let cell = view.cell as? NSTextFieldCell {
            cell.lineBreakMode = .byWordWrapping
            cell.wraps = true
            cell.isScrollable = false
        }
    }

    private func syncFocus(view: TaskNSTextField) {
        guard let window = view.window else { return }
        let isCurrentlyFocused = (window.firstResponder as? NSText)?.delegate === view
            || window.firstResponder === view
        if isFocused && !isCurrentlyFocused {
            window.makeFirstResponder(view)
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TaskTitleField
        init(_ parent: TaskTitleField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.onChange(field.stringValue)
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            parent.onFocusGained()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
                return true
            case #selector(NSResponder.deleteBackward(_:)):
                if textView.string.isEmpty {
                    return parent.onBackspaceEmpty()
                }
                return false
            default:
                return false
            }
        }
    }
}

final class TaskNSTextField: NSTextField {
    fileprivate weak var coordinator: TaskTitleField.Coordinator?

    override var intrinsicContentSize: NSSize {
        guard let cell = cell as? NSTextFieldCell else { return super.intrinsicContentSize }
        let width = max(bounds.width, 1)
        let size = cell.cellSize(forBounds: NSRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude))
        return NSSize(width: NSView.noIntrinsicMetric, height: ceil(size.height))
    }

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        invalidateIntrinsicContentSize()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        invalidateIntrinsicContentSize()
    }
}
