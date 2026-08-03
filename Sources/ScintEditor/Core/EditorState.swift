
import AppKit
import Foundationimport SwiftUI


@Observable final class EditorState {
    private(set) var sheet: SheetModel
    private(set) var menu: MenuModel
    let themer = EditorThemer()
    private(set) var themeRevision = 0
    var editing: AnyHashable?
    var caretSelections: [AnyHashable: NSRange] = [:]
    var caretRects: [AnyHashable: CGRect] = [:]
    var viewportRects: [AnyHashable: CGRect] = [:]
    var entryFrames: [AnyHashable: CGRect] = [:]

    var menuViewportRect: CGRect? {
        guard let editing,
              let entry = entryFrames[editing],
              let viewport = viewportRects[editing]
        else { return nil }
        return viewport.offsetBy(dx: entry.minX, dy: entry.minY)
    }

    init(
        sheet ref: Reference,
        menuItems: [MenuItem],
        makeBlocks: @escaping (MenuItem) -> [Sheet.Block]?
    ) {
        let sheet = SheetModel(ref)
        self.sheet = sheet
        self.menu = MenuModel(sheet: sheet, items: menuItems, makeBlocks: makeBlocks)
        activateTrailingText()
    }

    func setTheme(_ theme: Theme) {
        themer.theme = theme
        themeRevision &+= 1
    }

    func caretSelection(for id: AnyHashable) -> NSRange? { caretSelections[id] }

    func focusGained(id: AnyHashable) {
        guard let block = sheet.block(id: id) else { return }
        if case .text = block { enterEditing(id) }
        else { selectBlock(id) }
    }

    func editBlock(id: AnyHashable) {
        guard let block = sheet.block(id: id) else { return }
        if case .text = block { return }
        selectBlock(id)
        menu.edit(block, anchorRect: entryFrames[id] ?? .zero)
    }

    func setCaret(id: AnyHashable, selection: NSRange) {
        let changed = editing != id || caretSelections[id] != selection
        editing = id
        sheet.select(id)
        caretSelections[id] = selection
        if changed || menu.isOpen { updateMenu(allowOpen: false) }
    }

    func write(id: AnyHashable, text: String, selection: NSRange) {
        editing = id
        sheet.select(id)
        caretSelections[id] = selection
        let changed = sheet.write(text, to: id)
        if changed || menu.isOpen { updateMenu(allowOpen: changed) }
    }

    func updateEntryFrame(id: AnyHashable, frame: CGRect) {
        if entryFrames[id] != frame {
            entryFrames[id] = frame
            updateMenuAnchor(for: id)
        }
    }

    func updateCaretRect(id: AnyHashable, rect: CGRect) {
        if caretRects[id] != rect {
            caretRects[id] = rect
            updateMenuAnchor(for: id)
        }
    }

    func updateViewportRect(id: AnyHashable, rect: CGRect) {
        if viewportRects[id] != rect {
            viewportRects[id] = rect
        }
    }

    func commitMenuSelection() {
        let inserting = menu.isInserting
        guard let result = menu.commitSelection() else { return }
        acceptMenuResult(result, inserting: inserting)
    }

    func handleInput(_ selector: Selector, selection: NSRange, textLength: Int) -> Bool {
        if menu.isOpen {
            let inserting = menu.isInserting
            let result = menu.handleInput(selector)
            if let mutation = result.result { acceptMenuResult(mutation, inserting: inserting) }
            return result.handled
        }

        switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                guard editing == nil,
                      let id = sheet.selection.first,
                      let index = sheet.index(for: id),
                      let block = sheet.block(id: id)
                else { return false }
                if case .text = block { return false }
                return insertText(at: index + 1)
            case #selector(NSResponder.cancelOperation(_:)):
                return endEditing()
            case #selector(NSResponder.deleteBackward(_:)):
                return editing == nil ? deleteSelection() : deleteBackwardAtBlockStart(selection: selection)
            case #selector(NSResponder.moveUp(_:)):
                guard editing == nil || (selection.length == 0 && selection.location == 0) else { return false }
                return select(offset: -1)
            case #selector(NSResponder.moveDown(_:)), #selector(NSResponder.insertTab(_:)):
                guard editing == nil || (selection.length == 0 && selection.location == textLength) else { return false }
                return select(offset: 1)
            default:
                return false
        }
    }

    @discardableResult
    func beginEditingFromCanvasClick(at point: CGPoint) -> Bool {
        if menu.isOpen { menu.close() }
        let blocks = Sheet.with(sheet.ref, { $0.blocks }) ?? []
        guard !blocks.isEmpty else { return insertText(at: 0) }

        let framed = blocks.enumerated().compactMap { index, block -> (Int, Sheet.Block, CGRect)? in
            guard let frame = entryFrames[block.id] else { return nil }
            return (index, block, frame)
        }.sorted { $0.2.minY < $1.2.minY }

        if let hit = framed.first(where: { $0.2.contains(point) }) {
            return beginEditing(near: hit.1, insertingAfter: hit.0)
        }
        if let previous = framed.last(where: { point.y >= $0.2.maxY }) {
            return beginEditing(near: previous.1, insertingAfter: previous.0)
        }
        if let first = blocks.first(where: { if case .text = $0 { true } else { false } }) {
            return beginEditing(near: first, insertingAfter: 0, atStart: true)
        }
        return insertText(at: 0)
    }

    private func acceptMenuResult(_ result: (AnyHashable, NSRange?), inserting: Bool) {
        if let caret = result.1 { enterEditing(result.0, caret: caret) }
        else if inserting, let index = sheet.index(for: result.0) { ensureText(after: index) }
        else { selectBlock(result.0) }
    }

    private func select(offset: Int) -> Bool {
        guard let current = editing ?? sheet.selection.first,
              let target = Sheet.with(sheet.ref, { sheet -> Sheet.Block? in
                  guard let index = sheet.blocks.firstIndex(where: { $0.id == current }) else { return nil }
                  let target = index + offset
                  return sheet.blocks.indices.contains(target) ? sheet.blocks[target] : nil
              }) ?? nil
        else { return false }

        switch target {
            case .text(_, let text):
                let location = offset < 0 ? (text as NSString).length : 0
                enterEditing(target.id, caret: NSRange(location: location, length: 0))
            default:
                selectBlock(target.id)
        }
        return true
    }

    private func deleteBackwardAtBlockStart(selection: NSRange) -> Bool {
        guard let editing,
              selection.location == 0,
              selection.length == 0,
              let index = sheet.index(for: editing),
              index > 0
        else { return false }

        if let merged = sheet.mergeText(at: editing) {
            enterEditing(merged.id, caret: merged.caret)
        } else if let previous = Sheet.with(sheet.ref, { sheet -> Sheet.Block? in
            sheet.blocks.indices.contains(index - 1) ? sheet.blocks[index - 1] : nil
        }) ?? nil {
            selectBlock(previous.id)
        } else {
            return false
        }
        return true
    }

    private func deleteSelection() -> Bool {
        guard !sheet.selection.isEmpty else { return false }
        let landing = sheet.delete(sheet.selection)
        if let landing, let block = sheet.block(id: landing) {
            if case .text(_, let text) = block {
                enterEditing(landing, caret: NSRange(location: (text as NSString).length, length: 0))
            } else {
                selectBlock(landing)
            }
        } else {
            _ = insertText(at: 0)
        }
        return true
    }

    private func ensureText(after index: Int) {
        if let next = Sheet.with(sheet.ref, { sheet -> Sheet.Block? in
            let next = index + 1
            guard sheet.blocks.indices.contains(next), case .text = sheet.blocks[next] else { return nil }
            return sheet.blocks[next]
        }) ?? nil {
            enterEditing(next.id, caret: NSRange(location: 0, length: 0))
        } else {
            _ = insertText(at: index + 1)
        }
    }

    private func insertText(at index: Int) -> Bool {
        guard let id = sheet.insertText(at: index) else { return false }
        enterEditing(id, caret: NSRange(location: 0, length: 0))
        return true
    }

    private func beginEditing(near block: Sheet.Block, insertingAfter index: Int, atStart: Bool = false) -> Bool {
        if case .text(_, let text) = block {
            let location = atStart ? 0 : (text as NSString).length
            enterEditing(block.id, caret: NSRange(location: location, length: 0))
        } else {
            ensureText(after: index)
        }
        return true
    }

    private func enterEditing(_ id: AnyHashable, caret: NSRange? = nil) {
        removeTrailingEmptyText(excluding: id)
        editing = id
        sheet.select(id)
        if let caret { caretSelections[id] = caret }
        else if caretSelections[id] == nil, case .text(_, let text)? = sheet.block(id: id) {
            caretSelections[id] = NSRange(location: (text as NSString).length, length: 0)
        }
    }

    private func selectBlock(_ id: AnyHashable) {
        removeTrailingEmptyText(excluding: id)
        editing = nil
        sheet.select(id)
    }

    @discardableResult
    func activateTrailingText() -> AnyHashable? {
        guard let trailing = Sheet.with(sheet.ref, { $0.blocks.last }) ?? nil else {
            return insertText(at: 0) ? editing : nil
        }

        if case .text(_, let text) = trailing {
            enterEditing(trailing.id, caret: NSRange(location: (text as NSString).length, length: 0))
            return trailing.id
        }

        return insertText(at: Sheet.with(sheet.ref, { $0.blocks.endIndex }) ?? 0) ? editing : nil
    }

    func deactivate() {
        removeTrailingEmptyText()
        editing = nil
    }

    @discardableResult
    private func endEditing() -> Bool {
        guard let editing else { return false }
        let landing = removeTrailingEmptyText()
        self.editing = nil
        sheet.select(sheet.block(id: editing) == nil ? landing : editing)
        return true
    }

    @discardableResult
    private func removeTrailingEmptyText(excluding retainedID: AnyHashable? = nil) -> AnyHashable? {
        var landing: AnyHashable?

        while let trailing = Sheet.with(sheet.ref, { $0.blocks.last }) ?? nil,
              trailing.id != retainedID,
              case .text(_, let text) = trailing,
              text.isEmpty {
            caretSelections[trailing.id] = nil
            caretRects[trailing.id] = nil
            viewportRects[trailing.id] = nil
            entryFrames[trailing.id] = nil
            if editing == trailing.id { editing = nil }
            let next = sheet.delete([trailing.id])
            if sheet.selection.contains(trailing.id) { sheet.select(next) }
            landing = next
        }

        return landing
    }

    private func updateMenu(allowOpen: Bool) {
        guard allowOpen || menu.isOpen,
              let editing,
              case .text(_, let text)? = sheet.block(id: editing),
              let selection = caretSelections[editing]
        else {
            if menu.isOpen { menu.close() }
            return
        }

        let source = text as NSString
        let cursor = selection.location
        guard cursor > 0, cursor <= source.length else { menu.close(); return }

        var index = cursor - 1
        while index >= 0 {
            let character = source.substring(with: NSRange(location: index, length: 1))
            if character == "/" || character == "@" {
                if index > 0 {
                    let previous = source.substring(with: NSRange(location: index - 1, length: 1))
                    guard previous == " " || previous == "\t" || previous == "\n" else { menu.close(); return }
                }
                let queryRange = NSRange(location: index + 1, length: cursor - index - 1)
                let query = source.substring(with: queryRange)
                guard !query.contains(where: \.isWhitespace) else { menu.close(); return }
                menu.open(
                    kind: character == "/" ? .fixed : .dynamic,
                    query: query,
                    target: editing,
                    replacementRange: NSRange(location: index, length: cursor - index),
                    anchorRect: anchorRect(for: editing)
                )
                return
            }
            if character == " " || character == "\t" || character == "\n" { break }
            index -= 1
        }
        menu.close()
    }

    private func anchorRect(for id: AnyHashable) -> CGRect {
        guard let entry = entryFrames[id], let caret = caretRects[id] else { return entryFrames[id] ?? .zero }
        return caret.offsetBy(dx: entry.minX, dy: entry.minY)
    }

    private func updateMenuAnchor(for id: AnyHashable) {
        guard menu.isOpen, editing == id else { return }
        menu.anchorRect = anchorRect(for: id)
    }
}
