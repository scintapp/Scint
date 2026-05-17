import AppKit
import SwiftUI


private struct SegmentFramesKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct EditorContentView: View {
    @Environment(EditorModel.self) private var editor

    static let sharedStyler = EditorStyler()
    static let canvasSpace = "editorCanvas"

    let onCommand: (Selector) -> Bool
    let onTextChange: (() -> Void)?

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(editor.segments) { segment in
                input(for: segment)
                    .background(frameReader(for: segment.id))
            }
        }
        .onPreferenceChange(SegmentFramesKey.self) { frames in
            for (id, frame) in frames {
                editor.updateSegmentFrame(id, frame: frame)
            }
        }
    }

    private func input(for segment: EditorSegment) -> some View {
        let isFocused = editor.focusedSegmentID == segment.id

        return EditorInput(
            text: segment.text,
            renderVersion: editor.renderVersion,
            selection: segment.selection,
            isFocused: isFocused,
            hasFocusedTextEntry: isFocused,
            styler: Self.sharedStyler,
            makeInlineComponentView: { entry, activate in
                AnyView(InlineComponentView(entry: entry, activate: activate, update: editor.updateInlineEntry))
            },
            resolveComponent: { id in editor.componentEntry(for: id) },
            registerComponents: { entries in editor.registerInlineEntries(entries) },
            onTextChange: { newText, newSelection, caretRect in
                editor.write(segmentID: segment.id, text: newText, selection: newSelection, caretRect: caretRect)
                onTextChange?()
            },
            onSelectionChange: { newSelection, caretRect in
                editor.select(segmentID: segment.id, selection: newSelection, caretRect: caretRect)
            },
            onFocusGained: { editor.focusGained(segmentID: segment.id) },
            onActivateEntry: { entry in editor.activate(entry) },
            onCommand: onCommand
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func frameReader(for id: UUID) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: SegmentFramesKey.self,
                value: [id: proxy.frame(in: .named(Self.canvasSpace))]
            )
        }
    }
}
