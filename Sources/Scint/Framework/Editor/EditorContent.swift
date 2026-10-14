import SwiftUI
import ScintRuntime
import ScintComponents


@MainActor struct EditorContent {
    private let editor: EditorView

    init(editor: EditorView) { self.editor = editor }

    func spacing(_ block: Block, at index: Int, in blocks: [Block]) -> (gap: CGFloat, start: Int) {
        let above: Block? = index > 0 ? blocks[index - 1] : nil
        let first = EditorIO.markdown(block).flatMap { Markdown.scan($0).blocks.first }
        let gap: CGFloat = switch (above, block) {
            case (nil, _): 0
            case (.task?, .task): Typography.Prose.listItemSpacing
            default:
                if let last = above.flatMap(EditorIO.markdown).flatMap({ Markdown.scan($0).blocks.last }), let first { Styler.spacing(after: last.kind, before: first.kind) }
                else { Typography.Prose.blockSpacing }
        }
        var start = 0
        if let first, first.kind == .numbered {
            scan: for previous in blocks[..<index].reversed() {
                guard case .paragraph(_, let text) = previous, !text.isEmpty else { break }
                for line in Markdown.scan(text).blocks.reversed() {
                    guard line.kind.isList, line.depth >= first.depth else { break scan }
                    guard line.depth == first.depth else { continue }
                    guard line.kind == .numbered else { break scan }
                    start += 1
                }
            }
        }
        return (gap, start)
    }

    @ViewBuilder func view(_ block: Block, _ target: EditorFocus.Target, at index: Int, listStart start: Int) -> some View {
        switch block {
            case .paragraph(_, let text) where Markdown.Table(text) != nil:
                TableEditor(.init(get: { editor.io.text(of: block.id) }, set: { editor.io.write(block.id, $0) }))

            case .paragraph, .heading, .code:
                let text = EditorIO.markdown(block) ?? ""
                if editor.focus.editing != target {
                    BlockTextView(text: text, listStart: start, onClick: { editor.focus.edit(target, caret: $0) })
                } else {
                    MarkdownInput(ref: editor.ref, target: target, focus: editor.focus, listStart: start)
                }

            case .task(_, let text, let completed):
                TaskRow(
                    completed: completed,
                    onToggle: { editor.io.toggle(block.id) }
                ) {
                    if editor.focus.editing != target { BlockTextView(text: text, onClick: { editor.focus.edit(target, caret: $0) }) }
                    else { MarkdownInput(ref: editor.ref, target: target, focus: editor.focus, placeholder: "Task", commands: false) }
                }

            default:
                DocumentBlock(block: block, isSelected: editor.focus.selected == target, onSelect: { editor.focus.select(target) })
                    .onDrag { editor.drag(index) }
        }
    }
}
