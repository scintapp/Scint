import AppKit
import Foundation
import SwiftUI


private struct EntryFramesKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct DocumentContent: View {
    @Environment(EditorModel.self) private var editor
    static let canvasSpace = "editorCanvas"
    private static let styler = EditorStyler()
    let onCommand: (Selector, Bool, Bool) -> Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(editor.blocks) { entry in
                block(entry: entry)
                    .id(entry.id)
                    .background(frameReader(for: entry.id))
            }
        }
        .onPreferenceChange(EntryFramesKey.self) { frames in
            for (id, frame) in frames {
                editor.updateEntryFrame(id: id, frame: frame)
            }
        }
    }
    
    @ViewBuilder private func block(entry: Block) -> some View {
        switch entry {
        case .content(_, let text): input(id: entry.id, text: text)
        default: component(id: entry.id, block: entry)
        }
    }

    @ViewBuilder private func background(_ content: String) -> some View {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("```") {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Design.Background.card)
                .padding(.horizontal, 3)
                .padding(.vertical, 4)
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(.gray.opacity(0.04), lineWidth: 1)
                }
        }

        if trimmed.hasPrefix(">") {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Design.SheetGlyph.accent)
                    .frame(width: 3)
                Spacer(minLength: 0)
            }
        }
    }

    private func input(id: UUID, text: String) -> some View {
        EditorInput(
            id: id,
            text: text,
            selection: editor.caretSelection(for: id),
            isEditing: editor.isEditing(id: id),
            styler: Self.styler,
            onTextChange: { newText, newSelection in editor.write(id: id, text: newText, selection: newSelection) },
            onSelectionChange: { newSelection in editor.setCaret(id: id, selection: newSelection) },
            onFocusGained: { editor.focusGained(id: id) },
            onCommand: onCommand
        )
        .background { background(text) }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func component(id: UUID, block: Block) -> some View {
        SelectableEntry(
            id: id,
            block: block,
            isSelected: editor.isBlockSelected(id: id),
            onFocusGained: { editor.focusGained(id: id) },
            onCommand: { selector in editor.handleCommand(selector, atTopLine: true, atBottomLine: true) }
        ) {
            EditorSheet(block: block).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func frameReader(for id: UUID) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: EntryFramesKey.self,
                value: [id: proxy.frame(in: .named(Self.canvasSpace))]
            )
        }
    }
}
