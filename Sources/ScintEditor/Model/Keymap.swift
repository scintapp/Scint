import AppKit

@MainActor enum Keymap {
    struct Context {
        let editor: ScintEditor
        var menu: MenuController?
        var commitMenu: () -> Void = {}
        var cancelMenu: () -> Void = {}
        var onReturn: (() -> Bool)?
        var navigate: (NSTextSelectionNavigation.Direction, NSTextSelectionNavigation.Destination, Bool) -> Void = { _, _, _ in }
    }
    typealias Action = (Context) -> Void
    static let actions: [String: Action] = {
        var table: [String: Action] = [
            "insertNewline:": { c in
                if c.menu?.isOpen == true { c.commitMenu() }
                else if !c.editor.isTextPosition || c.onReturn?() != true { c.editor.newline() }
            },
            "insertLineBreak:": { $0.editor.type("\n") },
            "deleteBackward:": { $0.editor.deleteBackward() },
            "deleteForward:": { $0.editor.deleteForward() },
            "deleteWordBackward:": { $0.editor.deleteWordBackward() },
            "deleteWordForward:": { $0.editor.deleteWordForward() },
            "cancelOperation:": { c in c.editor.escape(); c.cancelMenu() },
            "selectAll:": { $0.editor.selectAll() },
            "insertTab:": { c in
                if c.menu?.isOpen == true { c.menu?.moveSelection(1) }
                else if c.editor.isListItem { c.editor.indent(by: 1) } else { c.editor.type("\t") }
            },
            "insertBacktab:": { c in
                if c.menu?.isOpen == true { c.menu?.moveSelection(-1) }
                else if c.editor.isListItem { c.editor.indent(by: -1) }
            }
        ]
        for extending in [false, true] {
            let suffix = extending ? "AndModifySelection:" : ":"
            table["moveLeft" + suffix] = { $0.editor.moveLeft(extending: extending) }
            table["moveRight" + suffix] = { $0.editor.moveRight(extending: extending) }
            table["moveWordLeft" + suffix] = { $0.editor.moveWordLeft(extending: extending) }
            table["moveWordRight" + suffix] = { $0.editor.moveWordRight(extending: extending) }
            for (name, direction) in [("moveUp", ScintEditor.Direction.up), ("moveDown", .down)] {
                table[name + suffix] = { c in
                    if c.menu?.isOpen == true { c.menu?.moveSelection(direction == .up ? -1 : 1) }
                    else if c.editor.isTextPosition { c.navigate(direction == .up ? .up : .down, .character, extending) }
                    else { c.editor.stepBlock(direction, extending: extending) }
                }
            }
            for (name, direction, destination) in [
                ("moveToBeginningOfLine", NSTextSelectionNavigation.Direction.backward, NSTextSelectionNavigation.Destination.line),
                ("moveToEndOfLine", .forward, .line), ("pageUp", .up, .container), ("pageDown", .down, .container)
            ] {
                table[name + suffix] = { c in if c.editor.isTextPosition { c.navigate(direction, destination, extending) } }
            }
            for (name, end) in [("moveToBeginningOfDocument", false), ("moveToEndOfDocument", true)] {
                table[name + suffix] = { c in
                    guard let block = end ? c.editor.blocks.last : c.editor.blocks.first else { return }
                    c.editor.land(on: block, atEnd: end)
                }
            }
        }
        return table
    }()
    static func performKeyEquivalent(_ event: NSEvent, host: EditorDocumentView) -> Bool {
        guard let responder = host.window?.firstResponder,
              responder === host || (responder as? ScintEditorView)?.host === host || (responder as? EditorCardView)?.host === host else { return false }
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard modifiers == .command || modifiers == [.command, .shift] else { return false }
        let shifted = modifiers.contains(.shift)
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "z":
            if shifted { host.editor.redo() } else { host.editor.undo() }
        case "f" where !shifted: host.performFindAction(.showFindInterface)
        case "g": host.performFindAction(shifted ? .previousMatch : .nextMatch)
        case "e" where !shifted: host.performFindAction(.setSearchString)
        default: return false
        }
        return true
    }
    static func validate(_ item: NSMenuItem, host: EditorDocumentView) -> Bool? {
        switch item.action.map(NSStringFromSelector) {
        case "undo:": return host.editor.undoManager.canUndo
        case "redo:": return host.editor.undoManager.canRedo
        case "performTextFinderAction:", "performFindPanelAction:":
            guard let action = NSTextFinder.Action(rawValue: item.tag) else { return false }
            return host.finder.validateAction(action)
        default: return nil
        }
    }
    static func handleMenu(_ selector: Selector, empty: Bool, move: (Int) -> Void, commit: () -> Void, cancel: () -> Void) -> Bool {
        switch NSStringFromSelector(selector) {
        case "moveDown:", "insertTab:": move(1)
        case "moveUp:", "insertBacktab:": move(-1)
        case "insertNewline:": commit()
        case "cancelOperation:": cancel()
        case "deleteBackward:" where empty: cancel()
        default: return false
        }
        return true
    }
    static func handle(_ selector: Selector, context: Context) -> Bool {
        guard let action = actions[NSStringFromSelector(selector)] else { return false }
        action(context); return true
    }
}
