import AgencyRuntime
import AppKit
import Foundation
import SwiftUI


typealias Block = Sheet.Block

@Observable final class EditorModel {
    let menu: MenuModel
    let sheet: Reference
    var selection: Set<UUID> = []
    var editing: UUID?
    var caretSelections: [UUID: NSRange] = [:]
    var entryFrames: [UUID: CGRect] = [:]
    var blocks: [Block] { Sheet.with(sheet, { $0.blocks }) ?? [] }

    private var editingPair: (id: UUID, index: Int)? {
        guard let editing, let index = index(for: editing) else { return nil }
        return (editing, index)
    }

    init(sheet: Reference, menu: MenuModel) {
        self.sheet = sheet
        self.menu = menu
        if let id = firstTextID() { enterEditing(id: id, caretAtEndOf: text(id: id) ?? "") }
    }

    var hasFocusedTextEntry: Bool {
        guard let editing, let entry = entry(id: editing) else { return false }
        if case .content = entry { return true }
        return false
    }

    var anchorRect: CGRect {
        guard let id = editing ?? selection.first, let frame = entryFrames[id] else { return .zero }
        return frame
    }

    func isEditing(id: UUID) -> Bool {
        editing == id
    }

    func isBlockSelected(id: UUID) -> Bool {
        editing == nil && selection.contains(id)
    }

    func caretSelection(for id: UUID) -> NSRange? {
        caretSelections[id]
    }

    func escapeEditing() {
        guard let editing else { return }
        selection = [editing]
        self.editing = nil
        if menu.isOpen { menu.close() }
    }

    func focusGained(id: UUID) {
        guard let entry = entry(id: id) else { return }
        if case .content = entry {
            guard editing != id else { return }
            enterEditing(id: id)
        } else {
            guard !(editing == nil && selection == [id]) else { return }
            selectBlock(id: id)
        }
    }

    func setCaret(id: UUID, selection: NSRange) {
        let changed = editing != id || caretSelections[id] != selection
        guard changed else { return }
        self.selection = [id]
        editing = id
        caretSelections[id] = selection
        if menu.isOpen {
            updateMenu(allowOpen: false)
        }
    }

    func updateEntryFrame(id: UUID, frame: CGRect) {
        if entryFrames[id] != frame { entryFrames[id] = frame }
    }

    func write(id: UUID, text: String, selection: NSRange) {
        guard let index = index(for: id) else { return }

        self.selection = [id]
        editing = id
        caretSelections[id] = selection

        let didChangeText = Sheet.update(sheet) { sheet -> Bool in
            guard sheet.blocks.indices.contains(index), case .content(let entryID, let previousText) = sheet.blocks[index]
            else { return false }
            guard previousText != text else { return false }
            sheet.blocks[index] = .content(entryID, text)
            return true
        } ?? false

        if didChangeText || menu.isOpen { updateMenu(allowOpen: didChangeText) }
    }

    func commitMenuSelection() {
        guard let commit = menu.commitSelection() else { return }
        insert(commit.entries, replacing: commit.replacementRange)
    }

    func handleCommand(_ selector: Selector, atTopLine: Bool, atBottomLine: Bool) -> Bool {
        if menu.isOpen {
            let result = menu.handleCommand(selector)
            if let commit = result.commit { insert(commit.entries, replacing: commit.replacementRange) }
            return result.handled
        }

        let inTextMode = editing != nil

        switch selector {

        case #selector(NSResponder.insertNewline(_:)):
            if inTextMode { return false }
            if let id = selection.first { ensureText(after: id) }
            return true

        case #selector(NSResponder.cancelOperation(_:)):
            guard inTextMode else { return false }
            escapeEditing()
            return true

        case #selector(NSResponder.deleteBackward(_:)):
            if inTextMode { return deleteBackwardAtBlockStart() }
            return deleteSelectedBlocks()

        case #selector(NSResponder.moveUp(_:)):
            if inTextMode {
                guard atTopLine else { return false }
                return selectAbove()
            }
            return selectAbove()

        case #selector(NSResponder.moveDown(_:)), #selector(NSResponder.insertTab(_:)):
            if inTextMode {
                guard atBottomLine else { return false }
                return selectBelow()
            }
            return selectBelow()

        default:
            return false
        }
    }

    @discardableResult
    func selectAbove() -> Bool {
        guard let currentID = editing ?? selection.first,
              let index = index(for: currentID),
              index > blocks.startIndex
        else { return false }

        let target = blocks[blocks.index(before: index)]
        moveSelection(to: target, enteringFromBelow: true)
        return true
    }

    @discardableResult
    func selectBelow() -> Bool {
        guard let currentID = editing ?? selection.first,
              let index = index(for: currentID)
        else { return false }

        let next = blocks.index(after: index)
        guard next < blocks.endIndex else { return false }

        let target = blocks[next]
        moveSelection(to: target, enteringFromBelow: false)
        return true
    }

    private func moveSelection(to target: Block, enteringFromBelow: Bool) {
        let wasEditing = editing != nil

        switch target {
        case .content(let id, let text):
            if wasEditing {
                let location = enteringFromBelow ? (text as NSString).length : 0
                enterEditing(id: id, caret: NSRange(location: location, length: 0))
            } else {
                selectBlock(id: id)
            }
        default:
            selectBlock(id: target.id)
        }
        if menu.isOpen { menu.close() }
    }

    func deleteBackwardAtBlockStart() -> Bool {
        guard let pair = editingPair,
              let selection = caretSelections[pair.id],
              selection.location == 0,
              selection.length == 0
        else { return false }

        let focusedIndex = pair.index

        let result = Sheet.update(sheet) { sheet -> (UUID, NSRange)? in
            guard sheet.blocks.indices.contains(focusedIndex),
                  focusedIndex > sheet.blocks.startIndex,
                  case .content(_, let text) = sheet.blocks[focusedIndex]
            else { return nil }

            let previousIndex = sheet.blocks.index(before: focusedIndex)

            if case .content(let previousID, let previousText) = sheet.blocks[previousIndex] {
                let focusLocation = (previousText as NSString).length
                sheet.blocks[previousIndex] = .content(previousID, previousText + text)
                sheet.blocks.remove(at: focusedIndex)
                return (previousID, NSRange(location: focusLocation, length: 0))
            }

            return nil
        }

        if let (id, caret) = result ?? nil {
            enterEditing(id: id, caret: caret)
            menu.close()
            return true
        }

        let index = pair.index
        guard index > blocks.startIndex else { return false }
        selectBlock(id: blocks[blocks.index(before: index)].id)
        return true
    }

    @discardableResult
    func deleteSelectedBlocks() -> Bool {
        guard editing == nil, !selection.isEmpty else { return false }
        let doomed = selection

        let landingID: UUID? = Sheet.update(sheet) { sheet -> UUID? in
            guard let firstIndex = sheet.blocks.firstIndex(where: { doomed.contains($0.id) })
            else { return nil }

            sheet.blocks.removeAll { doomed.contains($0.id) }

            guard !sheet.blocks.isEmpty else { return nil }
            let landingIndex = min(max(firstIndex - 1, 0), sheet.blocks.count - 1)
            return sheet.blocks[landingIndex].id
        } ?? nil

        if let landingID, let entry = entry(id: landingID) {
            if case .content = entry {
                enterEditing(id: landingID, caretAtEndOf: text(id: landingID) ?? "")
            } else {
                selectBlock(id: landingID)
            }
        } else if let id = firstTextID() {
            enterEditing(id: id, caretAtEndOf: text(id: id) ?? "")
        }
        menu.close()
        return true
    }

    private func insert(_ newEntries: [Block], replacing range: NSRange) {
        guard let pair = editingPair, !newEntries.isEmpty else { return }
        let focusedIndex = pair.index

        if newEntries.allSatisfy(\.isText) {
            let spliced: (UUID, NSRange)? = Sheet.update(sheet) { sheet -> (UUID, NSRange)? in
                guard sheet.blocks.indices.contains(focusedIndex),
                      case .content(let id, let text) = sheet.blocks[focusedIndex]
                else { return nil }
                let ns = text as NSString
                let replacementRange = clamped(range, in: text)
                let replacement = newEntries.textValue
                let next = ns.replacingCharacters(in: replacementRange, with: replacement)
                let caret = NSRange(
                    location: replacementRange.location + (replacement as NSString).length,
                    length: 0
                )
                sheet.blocks[focusedIndex] = .content(id, next)
                return (id, caret)
            } ?? nil

            if let (id, caret) = spliced { enterEditing(id: id, caret: caret) }
            return
        }

        let lastInsertedID: UUID? = Sheet.update(sheet) { sheet -> UUID? in
            guard sheet.blocks.indices.contains(focusedIndex),
                  case .content(let id, let text) = sheet.blocks[focusedIndex]
            else { return nil }

            let ns = text as NSString
            let replacementRange = clamped(range, in: text)
            let before = ns.substring(to: replacementRange.location)
            let after = ns.substring(from: replacementRange.location + replacementRange.length)

            var replacementEntries: [Block] = []
            if !before.isEmpty {
                replacementEntries.append(.content(id, before))
            }
            replacementEntries.append(contentsOf: newEntries)
            if !after.isEmpty {
                replacementEntries.append(.content(UUID(), after))
            }
            sheet.blocks.replaceSubrange(focusedIndex...focusedIndex, with: replacementEntries)
            return newEntries.last?.id
        } ?? nil

        if let lastInsertedID, let index = index(for: lastInsertedID) {
            ensureText(afterIndex: index)
        } else if let id = firstTextID() {
            enterEditing(id: id, caretAtEndOf: text(id: id) ?? "")
        }
    }

    func ensureText(after id: UUID) {
        guard let index = index(for: id) else { return }
        ensureText(afterIndex: index)
    }

    @discardableResult
    func beginEditingFromCanvasClick(at point: CGPoint) -> Bool {
        if menu.isOpen { menu.close() }

        let currentBlocks = blocks
        guard !currentBlocks.isEmpty else { return insertTextBlock(at: 0) != nil }

        let framedBlocks = currentBlocks.enumerated().compactMap { index, block -> (index: Int, block: Block, frame: CGRect)? in
            guard let frame = entryFrames[block.id] else { return nil }
            return (index, block, frame)
        }
        .sorted { $0.frame.minY < $1.frame.minY }

        if let hit = framedBlocks.first(where: { $0.frame.contains(point) }) {
            return beginEditing(near: hit.block, insertingAfter: hit.index)
        }

        if let previous = framedBlocks.last(where: { point.y >= $0.frame.maxY }) {
            ensureText(afterIndex: previous.index)
            return true
        }

        if let firstText = currentBlocks.first(where: \.isText) {
            return beginEditing(near: firstText, insertingAfter: 0, caretAtStart: true)
        }

        return insertTextBlock(at: 0) != nil
    }

    private func enterEditing(id: UUID, caret: NSRange? = nil, caretAtEndOf text: String? = nil) {
        let alreadyEditing = (editing == id && selection == [id])
        if !alreadyEditing {
            selection = [id]
            editing = id
        }
        if let caret { if caretSelections[id] != caret { caretSelections[id] = caret } }
        else if caretSelections[id] == nil {
            let value = text ?? (self.text(id: id) ?? "")
            caretSelections[id] = NSRange(location: (value as NSString).length, length: 0)
        }
    }

    private func selectBlock(id: UUID) {
        selection = [id]
        editing = nil
    }

    private func ensureText(afterIndex index: Int) {
        if let nextID = nextTextID(after: index) {
            enterEditing(id: nextID, caret: NSRange(location: 0, length: 0))
            return
        }
        _ = insertTextBlock(at: index + 1)
    }

    @discardableResult
    private func beginEditing(near block: Block, insertingAfter index: Int, caretAtStart: Bool = false) -> Bool {
        switch block {
        case .content(let id, let text):
            let location = caretAtStart ? 0 : (text as NSString).length
            enterEditing(id: id, caret: NSRange(location: location, length: 0))
            return true
        default:
            ensureText(afterIndex: index)
            return true
        }
    }

    @discardableResult
    private func insertTextBlock(at index: Int) -> UUID? {
        let newID = UUID()
        let inserted = Sheet.update(sheet) { sheet -> UUID in
            let insertAt = min(max(index, 0), sheet.blocks.count)
            sheet.blocks.insert(.content(newID, ""), at: insertAt)
            return newID
        } ?? nil

        if let inserted { enterEditing(id: inserted, caret: NSRange(location: 0, length: 0)) }
        return inserted
    }

    private func firstTextID() -> UUID? {
        blocks.first { entry in
            if case .content = entry { return true }
            return false
        }?.id
    }

    private func nextTextID(after index: Int) -> UUID? {
        let currentEntries = blocks
        guard index >= currentEntries.startIndex else { return nil }
        let start = currentEntries.index(after: index)
        guard start < currentEntries.endIndex else { return nil }
        for i in currentEntries.indices[start...] { if case .content(let id, _) = currentEntries[i] { return id } }
        return nil
    }

    private func entry(id: UUID) -> Block? {
        blocks.first { $0.id == id }
    }

    private func text(id: UUID) -> String? {
        guard case .content(_, let text) = entry(id: id) else { return nil }
        return text
    }

    private func index(for id: UUID) -> Int? {
        blocks.firstIndex { $0.id == id }
    }

    private func updateMenu(allowOpen: Bool) {
        guard allowOpen || menu.isOpen else { return }
        guard let trigger = detectTrigger() else {
            if menu.isOpen { menu.close() }
            return
        }
        menu.open(
            kind: trigger.kind,
            query: trigger.query,
            replacementRange: trigger.range,
            anchorRect: anchorRect
        )
    }

    private func detectTrigger() -> (kind: EditorMenuKind, query: String, range: NSRange)? {
        guard let editing,
              case .content(_, let text)? = entry(id: editing),
              let selection = caretSelections[editing]
        else { return nil }

        let ns = text as NSString
        let cursor = selection.location
        guard cursor > 0, cursor <= ns.length else { return nil }

        var index = cursor - 1
        while index >= 0 {
            let character = ns.substring(with: NSRange(location: index, length: 1))
            if character == "/" || character == "@" {
                guard isTriggerBoundary(before: index, in: text) else { return nil }
                let queryRange = NSRange(location: index + 1, length: cursor - index - 1)
                let query = ns.substring(with: queryRange)
                guard !query.contains(where: \.isWhitespace) else { return nil }
                return (
                    character == "/" ? .command : .reference,
                    query,
                    NSRange(location: index, length: cursor - index)
                )
            }
            if character == " " || character == "\t" || character == "\n" { return nil }
            index -= 1
        }
        return nil
    }

    private func isTriggerBoundary(before index: Int, in text: String) -> Bool {
        guard index > 0 else { return true }
        let previous = (text as NSString).substring(with: NSRange(location: index - 1, length: 1))
        return previous == " " || previous == "\t" || previous == "\n"
    }

    private func clamped(_ range: NSRange, in string: String) -> NSRange {
        let length = (string as NSString).length
        let location = min(max(range.location, 0), length)
        let maxLength = length - location
        return NSRange(location: location, length: min(range.length, maxLength))
    }
}

private extension Block {
    var isText: Bool {
        if case .content = self { return true }
        return false
    }
}

private extension Array where Element == Block {
    var textValue: String {
        compactMap { entry in
            if case .content(_, let value) = entry { return value }
            return nil
        }
        .joined()
    }
}
