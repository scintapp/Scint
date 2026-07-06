import AgencyRuntime
import AppKit
import Foundation
import SwiftUI


typealias Block = Sheet.Block

struct SheetTrigger {
    enum Kind { case command, reference }
    let kind: Kind, query: String, range: NSRange, anchorRect: CGRect
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

@Observable final class SheetModel {
    let ref: Reference
    var selection: Set<UUID> = []
    var editing: UUID?
    var caretSelections: [UUID: NSRange] = [:]
    var entryFrames: [UUID: CGRect] = [:]
    var blocks: [Block] { Sheet.with(ref, { $0.blocks }) ?? [] }

    private var editingPair: (id: UUID, index: Int)? {
        guard let editing, let index = index(for: editing) else { return nil }
        return (editing, index)
    }

    init(_ ref: Reference) {
        self.ref = ref
        if let id = firstTextID() { enterEditing(id: id, caretAtEndOf: text(id: id) ?? "") }
    }

    var anchorRect: CGRect {
        guard let id = editing ?? selection.first, let frame = entryFrames[id] else { return .zero }
        return frame
    }

    func isEditing(id: UUID) -> Bool { editing == id }
    func isBlockSelected(id: UUID) -> Bool { editing == nil && selection.contains(id) }
    func caretSelection(for id: UUID) -> NSRange? { caretSelections[id] }

    @discardableResult
    func escapeEditing() -> Bool {
        guard let editing else { return false }
        selection = [editing]
        self.editing = nil
        return true
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

    @discardableResult
    func setCaret(id: UUID, selection: NSRange) -> Bool {
        let changed = editing != id || caretSelections[id] != selection
        guard changed else { return false }
        self.selection = [id]
        editing = id
        caretSelections[id] = selection
        return true
    }

    func updateEntryFrame(id: UUID, frame: CGRect) {
        if entryFrames[id] != frame { entryFrames[id] = frame }
    }

    @discardableResult
    func write(id: UUID, text: String, selection: NSRange) -> Bool {
        guard let index = index(for: id) else { return false }
        self.selection = [id]
        editing = id
        caretSelections[id] = selection

        return Sheet.update(ref) { sheet -> Bool in
            guard sheet.blocks.indices.contains(index), case .content(let entryID, let previousText) = sheet.blocks[index]
            else { return false }
            guard previousText != text else { return false }
            sheet.blocks[index] = .content(entryID, text)
            return true
        } ?? false
    }

    func handleCommand(_ selector: Selector, atTopLine: Bool, atBottomLine: Bool) -> Bool {
        let inTextMode = editing != nil

        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            if inTextMode { return false }
            if let id = selection.first { ensureText(after: id) }
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            guard inTextMode else { return false }
            return escapeEditing()
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

        moveSelection(to: blocks[blocks.index(before: index)], enteringFromBelow: true)
        return true
    }

    @discardableResult
    func selectBelow() -> Bool {
        guard let currentID = editing ?? selection.first, let index = index(for: currentID)
        else { return false }

        let next = blocks.index(after: index)
        guard next < blocks.endIndex else { return false }
        moveSelection(to: blocks[next], enteringFromBelow: false)
        return true
    }

    func deleteBackwardAtBlockStart() -> Bool {
        guard let pair = editingPair,
              let selection = caretSelections[pair.id],
              selection.location == 0,
              selection.length == 0
        else { return false }

        let focusedIndex = pair.index
        let result = Sheet.update(ref) { sheet -> (UUID, NSRange)? in
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

        let landingID = Sheet.update(ref) { sheet -> UUID? in
            guard let firstIndex = sheet.blocks.firstIndex(where: { doomed.contains($0.id) })
            else { return nil }
            sheet.blocks.removeAll { doomed.contains($0.id) }
            guard !sheet.blocks.isEmpty else { return nil }
            return sheet.blocks[min(max(firstIndex - 1, 0), sheet.blocks.count - 1)].id
        } ?? nil

        if let landingID, let entry = entry(id: landingID) {
            if case .content = entry { enterEditing(id: landingID, caretAtEndOf: text(id: landingID) ?? "") }
            else { selectBlock(id: landingID) }
        } else if let id = firstTextID() {
            enterEditing(id: id, caretAtEndOf: text(id: id) ?? "")
        }
        return true
    }

    func insert(_ newEntries: [Block], replacing range: NSRange) {
        guard let pair = editingPair, !newEntries.isEmpty else { return }
        let focusedIndex = pair.index

        if newEntries.allSatisfy(\.isText) {
            let spliced = Sheet.update(ref) { sheet -> (UUID, NSRange)? in
                guard sheet.blocks.indices.contains(focusedIndex),
                      case .content(let id, let text) = sheet.blocks[focusedIndex]
                else { return nil }
                let replacementRange = clamped(range, in: text)
                let replacement = newEntries.textValue
                let next = (text as NSString).replacingCharacters(in: replacementRange, with: replacement)
                let caret = NSRange(location: replacementRange.location + (replacement as NSString).length, length: 0)
                sheet.blocks[focusedIndex] = .content(id, next)
                return (id, caret)
            } ?? nil

            if let (id, caret) = spliced { enterEditing(id: id, caret: caret) }
            return
        }

        let lastInsertedID = Sheet.update(ref) { sheet -> UUID? in
            guard sheet.blocks.indices.contains(focusedIndex),
                  case .content(let id, let text) = sheet.blocks[focusedIndex]
            else { return nil }

            let replacementRange = clamped(range, in: text)
            let ns = text as NSString
            let before = ns.substring(to: replacementRange.location)
            let after = ns.substring(from: replacementRange.location + replacementRange.length)
            var replacementEntries: [Block] = []
            if !before.isEmpty { replacementEntries.append(.content(id, before)) }
            replacementEntries.append(contentsOf: newEntries)
            if !after.isEmpty { replacementEntries.append(.content(UUID(), after)) }
            sheet.blocks.replaceSubrange(focusedIndex...focusedIndex, with: replacementEntries)
            return newEntries.last?.id
        } ?? nil

        if let lastInsertedID, let index = index(for: lastInsertedID) { ensureText(afterIndex: index) }
        else if let id = firstTextID() { enterEditing(id: id, caretAtEndOf: text(id: id) ?? "") }
    }

    func ensureText(after id: UUID) {
        guard let index = index(for: id) else { return }
        ensureText(afterIndex: index)
    }

    @discardableResult
    func beginEditingFromCanvasClick(at point: CGPoint) -> Bool {
        let currentBlocks = blocks
        guard !currentBlocks.isEmpty else { return insertTextBlock(at: 0) != nil }

        let framedBlocks = currentBlocks.enumerated().compactMap { index, block -> (index: Int, block: Block, frame: CGRect)? in
            guard let frame = entryFrames[block.id] else { return nil }
            return (index, block, frame)
        }.sorted { $0.frame.minY < $1.frame.minY }

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

    func menuTrigger() -> SheetTrigger? {
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
                return .init(
                    kind: character == "/" ? .command : .reference,
                    query: query,
                    range: NSRange(location: index, length: cursor - index),
                    anchorRect: anchorRect
                )
            }
            if character == " " || character == "\t" || character == "\n" { return nil }
            index -= 1
        }
        return nil
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
        default:
            ensureText(afterIndex: index)
        }
        return true
    }

    @discardableResult
    private func insertTextBlock(at index: Int) -> UUID? {
        let newID = UUID()
        let inserted = Sheet.update(ref) { sheet -> UUID in
            sheet.blocks.insert(.content(newID, ""), at: min(max(index, 0), sheet.blocks.count))
            return newID
        } ?? nil
        if let inserted { enterEditing(id: inserted, caret: NSRange(location: 0, length: 0)) }
        return inserted
    }

    private func firstTextID() -> UUID? { blocks.first(where: \.isText)?.id }

    private func nextTextID(after index: Int) -> UUID? {
        let currentEntries = blocks
        guard index >= currentEntries.startIndex else { return nil }
        let start = currentEntries.index(after: index)
        guard start < currentEntries.endIndex else { return nil }
        for i in currentEntries.indices[start...] { if case .content(let id, _) = currentEntries[i] { return id } }
        return nil
    }

    private func entry(id: UUID) -> Block? { blocks.first { $0.id == id } }

    private func text(id: UUID) -> String? {
        guard case .content(_, let text) = entry(id: id) else { return nil }
        return text
    }

    private func index(for id: UUID) -> Int? { blocks.firstIndex { $0.id == id } }

    private func isTriggerBoundary(before index: Int, in text: String) -> Bool {
        guard index > 0 else { return true }
        let previous = (text as NSString).substring(with: NSRange(location: index - 1, length: 1))
        return previous == " " || previous == "\t" || previous == "\n"
    }

    private func clamped(_ range: NSRange, in string: String) -> NSRange {
        let length = (string as NSString).length
        let location = min(max(range.location, 0), length)
        return NSRange(location: location, length: min(range.length, length - location))
    }
}

private struct EntryFramesKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct SheetView: View {
    @Environment(SheetModel.self) private var sheet
    let onTextChange: (UUID, String, NSRange) -> Void
    let onSelectionChange: (UUID, NSRange) -> Void
    let onFocusGained: (UUID) -> Void
    let onCommand: (Selector, Bool, Bool) -> Bool

    private func input(id: UUID, text: String) -> some View {
        EditorInput(
            id: id,
            text: text,
            selection: sheet.caretSelection(for: id),
            isEditing: sheet.isEditing(id: id),
            onTextChange: { newText, newSelection in onTextChange(id, newText, newSelection) },
            onSelectionChange: { newSelection in onSelectionChange(id, newSelection) },
            onFocusGained: { onFocusGained(id) },
            onCommand: onCommand
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func block(id: UUID, block: Block) -> some View {
        SheetBlock(
            id: id,
            block: block,
            isSelected: sheet.isBlockSelected(id: id),
            onFocusGained: { onFocusGained(id) },
            onCommand: { selector in onCommand(selector, true, true) }
        )
    }

    private func reader(for id: UUID) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(key: EntryFramesKey.self, value: [id: proxy.frame(in: .named("canvas"))])
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(sheet.blocks) { entry in
                Group {
                    switch entry {
                    case .content(_, let text): input(id: entry.id, text: text)
                    default: block(id: entry.id, block: entry)
                    }
                }
                .id(entry.id)
                .background(reader(for: entry.id))
            }
        }
        .onPreferenceChange(EntryFramesKey.self) { frames in
            for (id, frame) in frames { sheet.updateEntryFrame(id: id, frame: frame) }
        }
    }
}
