import AgencyRuntime
import AppKit
import Foundation
import SwiftUI


typealias Entry = Sheet.Entry

@Observable final class EditorModel {
    let sheet: Reference
    let menu: MenuModel
    var selection: Set<UUID> = []
    var editing: UUID?
    var caretSelections: [UUID: NSRange] = [:]
    var entryFrames: [UUID: CGRect] = [:]

    init(sheet: Reference, menu: MenuModel) {
        self.sheet = sheet
        self.menu = menu
        ensureEditableTextBlock()
        if let id = firstTextID() { enterEditing(id: id, caretAtEndOf: text(id: id) ?? "") }
    }

    var entries: [Entry] {
        Sheet.with(sheet, { $0.entries }) ?? []
    }

    func isEditing(id: UUID) -> Bool {
        editing == id
    }

    func isBlockSelected(id: UUID) -> Bool {
        editing == nil && selection.contains(id)
    }

    var hasFocusedTextEntry: Bool {
        guard let editing, let entry = entry(id: editing) else { return false }
        if case .text = entry { return true }
        return false
    }

    var anchorRect: CGRect {
        guard let id = editing ?? selection.first, let frame = entryFrames[id] else { return .zero }
        return frame
    }

    func caretSelection(for id: UUID) -> NSRange? {
        caretSelections[id]
    }

    private var editingPair: (id: UUID, index: Int)? {
        guard let editing, let index = index(for: editing) else { return nil }
        return (editing, index)
    }

    @discardableResult
    func ensureEditableTextBlock() -> UUID? {
        Sheet.update(sheet) { sheet -> UUID in
            if sheet.entries.isEmpty {
                let id = UUID()
                sheet.entries = [.text(id, "")]
                return id
            }
            if let last = sheet.entries.last, case .text(let id, _) = last { return id }
            let id = UUID()
            sheet.entries.append(.text(id, ""))
            return id
        } ?? nil
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

    func escapeEditing() {
        guard let editing else { return }
        selection = [editing]
        self.editing = nil
        if menu.isOpen { menu.close() }
    }

    func focusGained(id: UUID) {
        guard let entry = entry(id: id) else { return }
        if case .text = entry {
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
        if entryFrames[id] != frame {
            entryFrames[id] = frame
        }
    }

    func write(id: UUID, text: String, selection: NSRange) {
        guard let index = index(for: id) else { return }

        self.selection = [id]
        editing = id
        caretSelections[id] = selection

        let didChangeText = Sheet.update(sheet) { sheet -> Bool in
            guard sheet.entries.indices.contains(index),
                  case .text(let entryID, let previousText) = sheet.entries[index]
            else { return false }
            guard previousText != text else { return false }
            sheet.entries[index] = .text(entryID, text)
            return true
        } ?? false

        if didChangeText || menu.isOpen {
            updateMenu(allowOpen: didChangeText)
        }
    }

    func splitBlockAtCaret() -> Bool {
        guard let pair = editingPair,
              let caret = caretSelections[pair.id]
        else { return false }
        let focusedIndex = pair.index

        let newID: UUID? = Sheet.update(sheet) { sheet -> UUID? in
            guard sheet.entries.indices.contains(focusedIndex),
                  case .text(let id, let text) = sheet.entries[focusedIndex]
            else { return nil }
            let ns = text as NSString
            let split = min(max(caret.location, 0), ns.length)
            let before = ns.substring(to: split)
            let after = ns.substring(from: split)
            let newID = UUID()
            sheet.entries[focusedIndex] = .text(id, before)
            sheet.entries.insert(.text(newID, after), at: focusedIndex + 1)
            return newID
        } ?? nil

        guard let newID else { return false }
        enterEditing(id: newID, caret: NSRange(location: 0, length: 0))
        return true
    }

    func commitMenuSelection() {
        guard let commit = menu.commitSelection() else { return }
        insert(commit.entries, replacing: commit.replacementRange)
    }

    func handleCommand(_ selector: Selector, atTopLine: Bool, atBottomLine: Bool) -> Bool {
        if menu.isOpen {
            let result = menu.handleCommand(selector)
            if let commit = result.commit {
                insert(commit.entries, replacing: commit.replacementRange)
            }
            return result.handled
        }

        let inTextMode = editing != nil

        switch selector {
            
        case #selector(NSResponder.insertNewline(_:)):
            if inTextMode { return splitBlockAtCaret() }
            if let id = selection.first { ensureText(after: id) }
            return true

        case #selector(NSResponder.cancelOperation(_:)):
            guard inTextMode else { return false }
            escapeEditing()
            return true

        case #selector(NSResponder.deleteBackward(_:)):
            if inTextMode {
                return deleteBackwardAtBlockStart()
            }
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
              index > entries.startIndex
        else { return false }

        let target = entries[entries.index(before: index)]
        moveSelection(to: target, enteringFromBelow: true)
        return true
    }

    @discardableResult
    func selectBelow() -> Bool {
        guard let currentID = editing ?? selection.first,
              let index = index(for: currentID)
        else { return false }

        let next = entries.index(after: index)
        guard next < entries.endIndex else { return false }

        let target = entries[next]
        moveSelection(to: target, enteringFromBelow: false)
        return true
    }

    private func moveSelection(to target: Entry, enteringFromBelow: Bool) {
        let wasEditing = editing != nil

        switch target {
        case .text(let id, let text):
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
            guard sheet.entries.indices.contains(focusedIndex),
                  focusedIndex > sheet.entries.startIndex,
                  case .text(_, let text) = sheet.entries[focusedIndex]
            else { return nil }

            let previousIndex = sheet.entries.index(before: focusedIndex)

            if case .text(let previousID, let previousText) = sheet.entries[previousIndex] {
                let focusLocation = (previousText as NSString).length
                sheet.entries[previousIndex] = .text(previousID, previousText + text)
                sheet.entries.remove(at: focusedIndex)
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
        guard index > entries.startIndex else { return false }
        selectBlock(id: entries[entries.index(before: index)].id)
        return true
    }

    @discardableResult
    func deleteSelectedBlocks() -> Bool {
        guard editing == nil, !selection.isEmpty else { return false }
        let doomed = selection

        let landingID: UUID? = Sheet.update(sheet) { sheet -> UUID? in
            guard let firstIndex = sheet.entries.firstIndex(where: { doomed.contains($0.id) })
            else { return nil }

            sheet.entries.removeAll { doomed.contains($0.id) }

            guard !sheet.entries.isEmpty else { return nil }
            let landingIndex = min(max(firstIndex - 1, 0), sheet.entries.count - 1)
            return sheet.entries[landingIndex].id
        } ?? nil

        ensureEditableTextBlock()

        if let landingID, let entry = entry(id: landingID) {
            if case .text = entry {
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

    private func insert(_ newEntries: [Entry], replacing range: NSRange) {
        guard let pair = editingPair, !newEntries.isEmpty else { return }
        let focusedIndex = pair.index

        if newEntries.allSatisfy(\.isText) {
            let spliced: (UUID, NSRange)? = Sheet.update(sheet) { sheet -> (UUID, NSRange)? in
                guard sheet.entries.indices.contains(focusedIndex),
                      case .text(let id, let text) = sheet.entries[focusedIndex]
                else { return nil }
                let ns = text as NSString
                let replacementRange = clamped(range, in: text)
                let replacement = newEntries.textValue
                let next = ns.replacingCharacters(in: replacementRange, with: replacement)
                let caret = NSRange(
                    location: replacementRange.location + (replacement as NSString).length,
                    length: 0
                )
                sheet.entries[focusedIndex] = .text(id, next)
                return (id, caret)
            } ?? nil

            if let (id, caret) = spliced { enterEditing(id: id, caret: caret) }
            return
        }

        let lastInsertedID: UUID? = Sheet.update(sheet) { sheet -> UUID? in
            guard sheet.entries.indices.contains(focusedIndex),
                  case .text(let id, let text) = sheet.entries[focusedIndex]
            else { return nil }

            let ns = text as NSString
            let replacementRange = clamped(range, in: text)
            let before = ns.substring(to: replacementRange.location)
            let after = ns.substring(from: replacementRange.location + replacementRange.length)

            var replacementEntries: [Entry] = []
            if !before.isEmpty {
                replacementEntries.append(.text(id, before))
            }
            replacementEntries.append(contentsOf: newEntries)
            if !after.isEmpty {
                replacementEntries.append(.text(UUID(), after))
            }
            sheet.entries.replaceSubrange(focusedIndex...focusedIndex, with: replacementEntries)
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

    private func ensureText(afterIndex index: Int) {
        if let nextID = nextTextID(after: index) {
            enterEditing(id: nextID, caret: NSRange(location: 0, length: 0))
            return
        }
        let newID = UUID()
        Sheet.update(sheet) { sheet in
            let insertAt = min(index + 1, sheet.entries.count)
            sheet.entries.insert(.text(newID, ""), at: insertAt)
        }
        enterEditing(id: newID, caret: NSRange(location: 0, length: 0))
    }

    private func firstTextID() -> UUID? {
        entries.first { entry in
            if case .text = entry { return true }
            return false
        }?.id
    }

    private func nextTextID(after index: Int) -> UUID? {
        let currentEntries = entries
        guard index >= currentEntries.startIndex else { return nil }
        let start = currentEntries.index(after: index)
        guard start < currentEntries.endIndex else { return nil }
        for i in currentEntries.indices[start...] {
            if case .text(let id, _) = currentEntries[i] { return id }
        }
        return nil
    }

    private func entry(id: UUID) -> Entry? {
        entries.first { $0.id == id }
    }

    private func text(id: UUID) -> String? {
        guard case .text(_, let text) = entry(id: id) else { return nil }
        return text
    }

    private func index(for id: UUID) -> Int? {
        entries.firstIndex { $0.id == id }
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
              case .text(_, let text)? = entry(id: editing),
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

private extension Entry {
    var isText: Bool {
        if case .text = self { return true }
        return false
    }
}

private extension Array where Element == Entry {
    var textValue: String {
        compactMap { entry in
            if case .text(_, let value) = entry { return value }
            return nil
        }
        .joined()
    }
}
