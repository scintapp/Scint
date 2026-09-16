import Foundation
import Observation


extension ScintEditor {
    enum Step {
        case insertText(id: AnyHashable, offset: Int, text: String)
        case deleteText(id: AnyHashable, offset: Int, text: String)
        case insertBlock(Material.Block, after: AnyHashable?)
        case removeBlock(Material.Block, after: AnyHashable?)
        var id: AnyHashable {
            switch self {
            case .insertText(let id, _, _), .deleteText(let id, _, _): id
            case .insertBlock(let block, _), .removeBlock(let block, _): block.id
            }
        }
    }
    struct Group { var steps: [Step]; var before: Position; var after: Position; var kind: Kind }
    enum Kind { case typing, deleting, other
        var name: String { switch self { case .typing: "Typing"; case .deleting: "Delete"; case .other: "Edit" } }
    }
    func record(_ step: Step) {
        guard !registrationSuspended else { return }
        openGroup?.steps.append(step)
    }
    func beginGroup(_ kind: Kind = .other) {
        if groupDepth == 0 { openGroup = Group(steps: [], before: position, after: position, kind: kind) }
        groupDepth += 1
    }
    func endGroup() {
        guard groupDepth > 0 else { return }
        groupDepth -= 1
        guard groupDepth == 0, var group = openGroup else { return }
        openGroup = nil
        guard !group.steps.isEmpty else { return }
        group.after = position
        let now = clock()
        if canCoalesce(group, at: now) {
            undoStack[undoStack.count - 1].steps += group.steps
            undoStack[undoStack.count - 1].after = position
        } else {
            undoStack.append(group)
            undoManager.beginUndoGrouping()
            undoManager.registerUndo(withTarget: self) { editor in editor.undo() }
            undoManager.setActionName(group.kind.name)
            undoManager.endUndoGrouping()
        }
        redoStack.removeAll()
        lastEditTime = now; coalescingPosition = position
    }
    func command(_ kind: Kind, _ operation: () -> Void) {
        beginGroup(kind); operation(); endGroup()
    }
    private func canCoalesce(_ group: Group, at now: TimeInterval) -> Bool {
        guard let top = undoStack.last, top.kind == group.kind, group.kind != .other,
              coalescingPosition == group.before, now - lastEditTime < 1,
              let last = top.steps.last, group.steps.count == 1, let next = group.steps.first else { return false }
        switch (last, next) {
        case (.insertText(let id, let offset, let text), .insertText(let nextID, let nextOffset, let nextText)):
            guard id == nextID, nextOffset == offset + text.utf16.count,
                  text.count == 1, text != "\n", nextText.count == 1, nextText != "\n" else { return false }
            return !(nextText.first!.isWhitespace && text.last?.isWhitespace == false)
        case (.deleteText(let id, let offset, _), .deleteText(let nextID, let nextOffset, let nextText)):
            return id == nextID && (nextOffset + nextText.utf16.count == offset || nextOffset == offset)
        default: return false
        }
    }
    func undo() {
        if !undoManager.isUndoing { undoManager.undo(); return }
        guard let group = undoStack.popLast() else { return }
        registrationSuspended = true
        for step in group.steps.reversed() { replay(step, inverse: true) }
        registrationSuspended = false
        restore(group.before)
        redoStack.append(group); coalescingPosition = nil; setTrigger(nil)
        undoManager.registerUndo(withTarget: self) { editor in editor.redo() }
        undoManager.setActionName(group.kind.name)
    }
    func redo() {
        if !undoManager.isRedoing { undoManager.redo(); return }
        guard let group = redoStack.popLast() else { return }
        registrationSuspended = true
        for step in group.steps { replay(step, inverse: false) }
        registrationSuspended = false
        restore(group.after)
        undoStack.append(group); coalescingPosition = nil; setTrigger(nil)
        undoManager.registerUndo(withTarget: self) { editor in editor.undo() }
        undoManager.setActionName(group.kind.name)
    }
    private func restore(_ saved: Position) {
        place(saved)
    }
    private func replay(_ step: Step, inverse: Bool) {
        switch step {
        case .insertText(let id, let offset, let text):
            _ = inverse ? deleteRecorded(text, in: id, at: offset) : insert(text, in: id, at: offset)
        case .deleteText(let id, let offset, let text):
            _ = inverse ? insert(text, in: id, at: offset) : deleteRecorded(text, in: id, at: offset)
        case .insertBlock(let block, let after):
            _ = inverse ? removeRecorded(block) : insert(block, after: after)
        case .removeBlock(let block, let after):
            _ = inverse ? insert(block, after: after) : removeRecorded(block)
        }
    }
    private func deleteRecorded(_ text: String, in id: AnyHashable, at offset: Int) -> Bool {
        guard let value = string(id), offset >= 0, offset + text.utf16.count <= value.utf16.count,
              (value as NSString).substring(with: NSRange(location: offset, length: text.utf16.count)) == text else { return false }
        return delete(in: id, range: offset..<(offset + text.utf16.count))
    }
    private func removeRecorded(_ expected: Material.Block) -> Bool {
        guard block(expected.id) == expected else { return false }; return remove(expected.id)
    }
}
