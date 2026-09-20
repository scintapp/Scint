import AppKit
import ScintComponents
import ScintRuntime
import SwiftUI


/// The block stack: it renders a document's blocks and dispatches each to its own
/// surface. It carries no caret, no text selection and no component state — a block id
/// and an `EditEvent` are the whole of what crosses this line. Focus is SwiftUI's,
/// keyed by block id and mirrored from the model in one place.
struct EditCanvas: View {
    @Environment(EditModel.self) private var editor
    @FocusState private var focus: AnyHashable?

    var body: some View {
        // Binds to whatever scroll view the canvas was put in, or none. Blocks are the
        // only thing it knows how to reveal; a surface is never asked where its caret is.
        ScrollViewReader { scroll in
            VStack(alignment: .leading, spacing: Style.Spacing.heading) {
                ForEach(editor.blocks) { block in
                    content(block).id(block.id)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(menu)
            .onChange(of: editor.focused, initial: true) { _, id in
                focus = id
                guard let id else { return }
                scroll.scrollTo(id)
            }
        }
    }

    @ViewBuilder private func content(_ block: Document.Block) -> some View {
        switch block {
            case .text(_, let text):
                EditText(
                    text: text,
                    isFocused: editor.focused == block.id,
                    entry: editor.entry,
                    defers: editor.menu.isOpen,
                    onEvent: { editor.handle($0, from: block.id) }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            default:
                // Nothing wraps or intercepts the block: it keeps its own mouse, and the
                // keys below are the canvas's defaults for a surface that wants none.
                // A component that wants the keyboard takes focus itself and hands it
                // back by reporting `.exit`.
                DocumentBlock(block: block, isSelected: editor.isSelected(block.id))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .focusable(editor.isSelected(block.id))
                    .focused($focus, equals: block.id)
                    .simultaneousGesture(TapGesture().onEnded { editor.focus(block.id) })
                    .onKeyPress(.upArrow) { send(.exit(.start), from: block.id) }
                    .onKeyPress(.downArrow) { send(.exit(.end), from: block.id) }
                    .onKeyPress(.return) { send(.newline(0), from: block.id) }
                    .onKeyPress(.delete) { send(.deleteAtStart, from: block.id) }
                    .onKeyPress(.escape) { send(.escape, from: block.id) }
        }
    }

    /// A key the canvas didn't act on stays the block's to use.
    private func send(_ event: EditEvent, from id: AnyHashable) -> KeyPress.Result {
        editor.handle(event, from: id) ? .handled : .ignored
    }

    /// ScintKit's floating panel. It stays non-key for the command and reference lists
    /// so the caret never leaves the block, and takes key for a form that needs typing.
    private var menu: some View {
        MenuPanelHost(
            controller: editor.menu,
            isOpen: editor.menu.isOpen,
            anchor: editor.menu.anchorRect,
            size: editor.menu.size,
            onSelect: { editor.menu.select($0); editor.commitMenu() },
            onCancel: { editor.closeMenu() },
            onCommit: { editor.commitMenu() }
        )
    }
}

