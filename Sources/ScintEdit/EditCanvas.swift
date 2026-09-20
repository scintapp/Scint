import AppKit
import ScintComponents
import ScintRuntime
import SwiftUI


struct EditCanvas: View {
    @Environment(EditModel.self) private var editor
    @FocusState private var focus: AnyHashable?

    var body: some View {
        ScrollViewReader { scroll in
            VStack(alignment: .leading, spacing: Style.Spacing.heading) {
                ForEach(editor.blocks) { block in
                    content(block).id(block.id)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(menu)
            .onChange(of: editor.focused, initial: true) { _, id in
                focus = editor.editing ? nil : id
                guard let id else { return }
                scroll.scrollTo(id)
            }
        }
    }

    @ViewBuilder private func content(_ block: ScintRuntime.Document.Block) -> some View {
        switch block {
            case .text(_, let text):
                EditText(
                    text: text,
                    isFocused: editor.focused == block.id,
                    entry: editor.entry,
                    defers: editor.menu.isOpen,
                    onEvent: { editor.handle($0, from: block.id) }
                )
                .frame(maxWidth: 660, alignment: .leading)

            default:
                DocumentBlock(block: block, isSelected: editor.isSelected(block.id))
                    .frame(maxWidth: 660, alignment: .leading)
                    .contentShape(Rectangle())
                    .focusable(editor.isSelected(block.id))
                    .focused($focus, equals: block.id)
                    .simultaneousGesture(TapGesture().onEnded { editor.focus(block.id) })
                    .onKeyPress { key($0, on: block.id) }
        }
    }

    private func key(_ press: KeyPress, on id: AnyHashable) -> KeyPress.Result {
        switch press.key {
            case .upArrow: return send(.exit(.start), from: id)
            case .downArrow, .tab: return send(.exit(.end), from: id)
            case .return: return send(.newline, from: id)
            case .escape: return send(.escape, from: id)
            case .delete, .deleteForward: return send(.deleteAtStart, from: id)
            default: break
        }
        let backspace = press.characters.unicodeScalars.contains { $0.value == 0x08 || $0.value == 0x7F }
        return backspace ? send(.deleteAtStart, from: id) : .ignored
    }

    private func send(_ event: EditEvent, from id: AnyHashable) -> KeyPress.Result {
        editor.handle(event, from: id) ? .handled : .ignored
    }

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

