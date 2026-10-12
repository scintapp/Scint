import AppKit
import SwiftUI


struct EditorRepresentable: NSViewRepresentable {
    @Binding var text: String
    let isFocused: Bool
    let onFocus: () -> Void
    let onMovePastBoundary: (EditorFocus.Offset) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            onFocus: onFocus,
            onMovePastBoundary: onMovePastBoundary
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView(usingTextLayoutManager: true)

        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.borderType = .noBorder

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        context.coordinator.text = $text
        context.coordinator.onFocus = onFocus
        context.coordinator.onMovePastBoundary = onMovePastBoundary
        context.coordinator.wantsFocus = isFocused

        if textView.string != text {
            textView.string = text
        }

        if isFocused {
            DispatchQueue.main.async {
                guard context.coordinator.wantsFocus else { return }
                textView.window?.makeFirstResponder(textView)
            }
        } else if textView.window?.firstResponder === textView {
            textView.window?.makeFirstResponder(nil)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var onFocus: () -> Void
        var onMovePastBoundary: (EditorFocus.Offset) -> Bool
        var wantsFocus = false

        init(
            text: Binding<String>,
            onFocus: @escaping () -> Void,
            onMovePastBoundary: @escaping (EditorFocus.Offset) -> Bool
        ) {
            self.text = text
            self.onFocus = onFocus
            self.onMovePastBoundary = onMovePastBoundary
        }

        func textDidBeginEditing(_ notification: Notification) {
            onFocus()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  textView.window?.firstResponder === textView else { return }

            onFocus()
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            let offset: EditorFocus.Offset

            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                offset = .previous
            case #selector(NSResponder.moveDown(_:)):
                offset = .next
            default:
                return false
            }

            guard caretIsOnBoundary(in: textView, offset: offset) else { return false }
            guard onMovePastBoundary(offset) else { return false }

            wantsFocus = false
            textView.window?.makeFirstResponder(nil)

            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView, !self.wantsFocus,
                      textView.window?.firstResponder === textView else { return }

                textView.window?.makeFirstResponder(nil)
            }
            return true
        }

        private func caretIsOnBoundary(
            in textView: NSTextView,
            offset: EditorFocus.Offset
        ) -> Bool {
            let selection = textView.selectedRange()
            guard selection.length == 0 else { return false }

            let caretRect = textView.firstRect(
                forCharacterRange: NSRange(location: selection.location, length: 0),
                actualRange: nil
            )
            let boundaryLocation = offset == .next
                ? (textView.string as NSString).length
                : 0
            let boundaryRect = textView.firstRect(
                forCharacterRange: NSRange(location: boundaryLocation, length: 0),
                actualRange: nil
            )

            return abs(caretRect.midY - boundaryRect.midY)
                < max(caretRect.height, boundaryRect.height) / 2
        }
    }
}
