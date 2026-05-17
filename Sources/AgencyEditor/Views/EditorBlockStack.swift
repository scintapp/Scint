import AppKit
import SwiftUI

private struct SegmentFramesKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct EditorBlockStack: View {
    @Environment(EditorModel.self) private var editor

    static let sharedStyler = EditorStyler()
    static let canvasSpace = "editorCanvas"

    let mode: EditorCanvas.Mode
    let onCommand: (Selector) -> Bool
    let onSegmentTextChange: (() -> Void)?

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(editor.segments) { segment in
                segmentRow(segment)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(
                                    key: SegmentFramesKey.self,
                                    value: [segment.id: proxy.frame(in: .named(Self.canvasSpace))]
                                )
                        }
                    )
            }
        }
        .onPreferenceChange(SegmentFramesKey.self) { frames in
            for (id, frame) in frames {
                editor.updateSegmentFrame(id, frame: frame)
            }
        }
    }

    @ViewBuilder
    private func segmentRow(_ segment: EditorSegment) -> some View {
        switch segment {
        case .text(let s):
            textRow(s)
        case .task(let t):
            EditorTaskBlock(segment: t)
                .padding(.vertical, 4)
        }
    }

    private func textRow(_ s: EditorSegment.TextSegment) -> some View {
        let isFocused = editor.focusedSegmentID == s.id
        return EditorInput(
            text: s.text,
            renderVersion: editor.renderVersion,
            selection: s.selection,
            isFocused: isFocused,
            hasFocusedTextEntry: isFocused,
            styler: Self.sharedStyler,
            makeInlineComponentView: { entry, activate in
                AnyView(InlineComponentView(entry: entry, activate: activate))
            },
            resolveComponent: { id in editor.componentEntry(for: id) },
            registerComponents: { entries in editor.registerInlineEntries(entries) },
            onTextChange: { newText, newSelection, caretRect in
                editor.write(segmentID: s.id, text: newText, selection: newSelection, caretRect: caretRect)
                onSegmentTextChange?()
            },
            onSelectionChange: { newSelection, caretRect in
                editor.select(segmentID: s.id, selection: newSelection, caretRect: caretRect)
            },
            onFocusGained: { editor.focusGained(segmentID: s.id) },
            onActivateEntry: { entry in editor.activate(entry) },
            onCommand: onCommand
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

