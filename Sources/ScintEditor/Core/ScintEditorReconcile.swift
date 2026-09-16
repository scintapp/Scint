import Foundation
import Observation

extension ScintEditor {
    func reconcileText(id: AnyHashable, prefix: Int, removed: Int, inserted: Int) {
        guard removed != 0 || inserted != 0, let text = string(id) else { return }
        func map(_ offset: Int) -> Int {
            if offset <= prefix { return offset }
            if offset >= prefix + removed { return offset + inserted - removed }
            return prefix + inserted
        }
        func mapPosition(_ position: Position, snap: Bool) -> Position {
            guard case .text(id, let anchor, let head) = position else { return position }
            return .text(id: id, anchor: snap ? Self.snap(map(anchor), in: text) : map(anchor),
                         head: snap ? Self.snap(map(head), in: text) : map(head))
        }
        func mapGroup(_ group: Group) -> Group {
            var group = group
            group.before = mapPosition(group.before, snap: false)
            group.after = mapPosition(group.after, snap: false)
            group.steps = group.steps.map { step in
                switch step {
                case .insertText(id, let offset, let value):
                    return .insertText(id: id, offset: removed == 0 && offset == prefix ? offset + inserted : map(offset), text: value)
                case .deleteText(id, let offset, let value):
                    return .deleteText(id: id, offset: map(offset), text: value)
                default: return step
                }
            }
            return group
        }
        // History is never discarded. Replay validates exact text and block payloads,
        // and traps with the material, block and step if the runtime cannot honor it.
        undoStack = undoStack.map(mapGroup); redoStack = redoStack.map(mapGroup)
        place(mapPosition(position, snap: true)); coalescingPosition = nil
        validateTrigger()
    }
    func reconcileBlocks() {
        let current = blocks
        guard !current.isEmpty else { place(.empty); positionIndex = 0; return }
        switch position {
        case .empty: land(on: current.last!, atEnd: true)
        case .text(let id, _, _):
            if string(id) == nil { land(on: current[min(positionIndex, current.count - 1)], atEnd: true) }
        case .blocks(let anchor, let head):
            let hasAnchor = block(anchor) != nil, hasHead = block(head) != nil
            if !hasAnchor || !hasHead {
                if hasAnchor { place(.blocks(anchor: anchor, head: anchor)) }
                else if hasHead { place(.blocks(anchor: head, head: head)) }
                else { land(on: current[min(positionIndex, current.count - 1)], atEnd: true) }
            }
        }
        positionIndex = current.firstIndex { $0.id == position.id } ?? positionIndex
    }
}
