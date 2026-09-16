import Foundation
import Observation

extension ScintEditor {
    func moveLeft(extending: Bool) { move(.up, extending: extending, word: false) }
    func moveRight(extending: Bool) { move(.down, extending: extending, word: false) }
    func moveWordLeft(extending: Bool) { move(.up, extending: extending, word: true) }
    func moveWordRight(extending: Bool) { move(.down, extending: extending, word: true) }
    func wordBoundary(_ offset: Int, in text: String, direction: Direction) -> Int {
        let source = text as NSString
        var boundaries: [Int] = []
        source.enumerateSubstrings(in: NSRange(location: 0, length: source.length), options: .byWords) { _, range, _, _ in
            boundaries.append(direction == .up ? range.location : NSMaxRange(range))
        }
        return direction == .up ? boundaries.last(where: { $0 < offset }) ?? 0 : boundaries.first(where: { $0 > offset }) ?? source.length
    }
    private func move(_ direction: Direction, extending: Bool, word: Bool) {
        guard case .text(let id, let anchor, let head) = position, let text = string(id) else {
            stepBlock(direction, extending: extending); return
        }
        if anchor != head && !extending {
            let end = direction == .up ? min(anchor, head) : max(anchor, head)
            place(.text(id: id, anchor: end, head: end)); return
        }
        let source = text as NSString
        if direction == .up ? head == 0 : head == source.length {
            if !extending { crossBoundary(direction) }; return
        }
        let next = word ? wordBoundary(head, in: text, direction: direction) :
            (direction == .up ? source.rangeOfComposedCharacterSequence(at: head - 1).location : NSMaxRange(source.rangeOfComposedCharacterSequence(at: head)))
        place(.text(id: id, anchor: extending ? anchor : next, head: next))
    }
    func crossBoundary(_ direction: Direction) {
        guard let index = blocks.firstIndex(where: { $0.id == position.id }) else { return }
        let next = index + (direction == .up ? -1 : 1)
        guard blocks.indices.contains(next) else { return }
        place(.blocks(anchor: blocks[next].id, head: blocks[next].id))
    }
    func stepBlock(_ direction: Direction, extending: Bool) {
        guard case .blocks(let anchor, let head) = position,
              let index = blocks.firstIndex(where: { $0.id == head }) else { return }
        let next = index + (direction == .up ? -1 : 1)
        guard blocks.indices.contains(next) else { return }
        let block = blocks[next]
        if extending { place(.blocks(anchor: anchor, head: block.id)) }
        else { land(on: block, atEnd: direction == .up) }
    }
    func land(on block: Material.Block, atEnd: Bool) {
        if case .text(_, let value) = block {
            let offset = atEnd ? value.utf16.count : 0
            place(.text(id: block.id, anchor: offset, head: offset))
        } else { place(.blocks(anchor: block.id, head: block.id)) }
    }
    func type(_ value: String) {
        if case .empty = position {
            guard !value.isEmpty else { return }
            command(.typing) {
                let block = Material.Block.text(UUID(), "")
                insert(block, after: nil)
                land(on: block, atEnd: false); type(value)
            }
            return
        }
        guard case .text(let id, let anchor, let head) = position, let source = string(id) else { return }
        let text = Self.normalized(value), lower = min(anchor, head), upper = max(anchor, head)
        command(.typing) {
            if lower != upper { delete(in: id, range: lower..<upper) }
            insert(text, in: id, at: lower)
            let end = lower + text.utf16.count
            place(.text(id: id, anchor: end, head: end))
            if text == "/" || text == "@" {
                let before = lower == 0 ? "" : (source as NSString).substring(with: NSRange(location: lower - 1, length: 1))
                if lower == 0 || [" ", "\t", "\n"].contains(before) { setTrigger(Trigger(id: id, offset: lower, character: text)) }
            }
            validateTrigger()
        }
    }
    func deleteBackward() { deleteDirection(.up, word: false) }
    func deleteForward() { deleteDirection(.down, word: false) }
    func deleteWordBackward() { deleteDirection(.up, word: true) }
    func deleteWordForward() { deleteDirection(.down, word: true) }
    private func deleteDirection(_ direction: Direction, word: Bool) {
        guard case .text(let id, let anchor, let head) = position, let text = string(id) else { removeSelectedBlocks(); return }
        command(.deleting) {
            var lower = min(anchor, head), upper = max(anchor, head)
            if lower == upper {
                let source = text as NSString
                if direction == .up ? head == 0 : head == source.length {
                    guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
                    let next = index + (direction == .up ? -1 : 1)
                    guard blocks.indices.contains(next) else { return }
                    let neighbor = blocks[next].id
                    if text.isEmpty { remove(id) }
                    place(.blocks(anchor: neighbor, head: neighbor)); return
                }
                let end = word ? wordBoundary(head, in: text, direction: direction) :
                    (direction == .up ? source.rangeOfComposedCharacterSequence(at: head - 1).location : NSMaxRange(source.rangeOfComposedCharacterSequence(at: head)))
                lower = min(head, end); upper = max(head, end)
            }
            delete(in: id, range: lower..<upper)
            place(.text(id: id, anchor: lower, head: lower))
        }
    }
    func newline() {
        if case .empty = position {
            command(.other) {
                let block = Material.Block.text(UUID(), "")
                insert(block, after: nil); land(on: block, atEnd: false)
            }
            return
        }
        if isTextPosition { type("\n"); return }
        guard case .blocks(let anchor, let head) = position, let block = block(head) else { return }
        command(.other) {
            guard anchor == head else { place(.blocks(anchor: head, head: head)); return }
            if case .text = block { land(on: block, atEnd: true); return }
            let index = blocks.firstIndex { $0.id == head }!
            if blocks.indices.contains(index + 1), case .text = blocks[index + 1] { land(on: blocks[index + 1], atEnd: false) }
            else {
                let text = Material.Block.text(UUID(), "")
                if insert(text, after: head) { land(on: text, atEnd: false) }
            }
        }
    }
    func selectAll() {
        if case .text(let id, let anchor, let head) = position, let text = string(id),
           min(anchor, head) != 0 || max(anchor, head) != text.utf16.count {
            place(.text(id: id, anchor: 0, head: text.utf16.count)); return
        }
        guard let first = blocks.first, let last = blocks.last else { return }
        place(.blocks(anchor: first.id, head: last.id))
    }
    func escape() {
        if trigger != nil { setTrigger(nil); return }
        if let id = position.id { place(.blocks(anchor: id, head: id)) }
    }
    func replace(in id: AnyHashable, range: Range<Int>, with value: String) {
        guard let source = string(id), range.lowerBound >= 0, range.upperBound <= source.utf16.count else { return }
        let text = Self.normalized(value)
        command(.other) {
            let old = position
            delete(in: id, range: range); insert(text, in: id, at: range.lowerBound)
            if case .text(id, _, let head) = old, range.contains(head) || head == range.upperBound {
                let end = range.lowerBound + text.utf16.count
                place(.text(id: id, anchor: end, head: end))
            } else if case .text(id, let anchor, let head) = old, let current = string(id) {
                // An unchanged position must still be within the edited string.
                place(.text(id: id, anchor: min(anchor, current.utf16.count), head: min(head, current.utf16.count)))
            }
            validateTrigger()
        }
    }
    var isListItem: Bool {
        guard case .text(let id, _, let head) = position, let text = string(id) else { return false }
        return Markdown.scan(text).blocks.first { head >= $0.range.location && head <= NSMaxRange($0.range) }?.kind.isList == true
    }
    func indent(by levels: Int) {
        guard case .text(let id, let anchor, let head) = position, let text = string(id),
              let block = Markdown.scan(text).blocks.first(where: { head >= $0.range.location && head <= NSMaxRange($0.range) }), block.kind.isList else { return }
        let line = (text as NSString).substring(with: block.range), next = Markdown.indented(line, by: levels)
        let prefix = (next as NSString).substring(to: Markdown.prefixLength(of: next))
        let delta = next.utf16.count - line.utf16.count
        guard delta != 0 else { return }
        command(.other) {
            replace(in: id, range: block.prefix.location..<NSMaxRange(block.prefix), with: prefix)
            place(.text(id: id, anchor: max(block.range.location, anchor + delta), head: max(block.range.location, head + delta)))
        }
    }
    func insertCard(_ card: Material.Block) {
        guard case .text = card else { insertNonTextCard(card); return }
    }
    private func insertNonTextCard(_ card: Material.Block) {
        guard block(card.id) == nil else { return }
        switch card {
        case .artifact(let ref): guard ref.type == Artifact.self else { return }
        case .command(let ref): guard ref.type == Command.self else { return }
        case .material(let ref): guard ref.type == Material.self else { return }
        default: break
        }
        command(.other) {
            switch position {
            case .empty:
                guard insert(card, after: nil) else { return }
            case .text(let id, _, let head):
                guard let text = string(id), let index = blocks.firstIndex(where: { $0.id == id }) else { return }
                let predecessor = index == 0 ? nil : blocks[index - 1].id
                if head == 0 { guard insert(card, after: predecessor) else { return } }
                else if head == text.utf16.count { guard insert(card, after: id) else { return } }
                else {
                    let source = text as NSString
                    var tail = source.substring(from: head)
                    delete(in: id, range: head..<source.length)
                    if source.substring(to: head).hasSuffix("\n") { delete(in: id, range: (head - 1)..<head) }
                    insert(card, after: id)
                    if tail.hasPrefix("\n") { tail.removeFirst() }
                    insert(.text(UUID(), tail), after: card.id)
                }
            case .blocks(_, let head):
                guard insert(card, after: head) else { return }
            }
            place(.blocks(anchor: card.id, head: card.id))
        }
    }
    var selectedBlockIDs: [AnyHashable] {
        guard case .blocks(let anchor, let head) = position,
              let a = blocks.firstIndex(where: { $0.id == anchor }), let h = blocks.firstIndex(where: { $0.id == head }) else { return [] }
        return blocks[min(a, h)...max(a, h)].map(\.id)
    }
    func removeSelectedBlocks() {
        let ids = selectedBlockIDs
        guard let first = ids.first, let last = ids.last,
              let start = blocks.firstIndex(where: { $0.id == first }), let end = blocks.firstIndex(where: { $0.id == last }) else { return }
        let before = start > 0 ? blocks[start - 1] : nil, after = end + 1 < blocks.count ? blocks[end + 1] : nil
        command(.other) {
            for id in ids.reversed() { remove(id) }
            if case .text(_, let lhs)? = before, case .text(_, let rhs)? = after, let before, let after {
                let separator = lhs.isEmpty || lhs.hasSuffix("\n") || rhs.isEmpty ? "" : "\n"
                let join = lhs.utf16.count + separator.utf16.count
                insert(separator + rhs, in: before.id, at: lhs.utf16.count); remove(after.id)
                place(.text(id: before.id, anchor: join, head: join))
            } else if let before { land(on: before, atEnd: true) }
            else if let after { land(on: after, atEnd: false) }
            else {
                let empty = Material.Block.text(UUID(), "")
                insert(empty, after: nil); land(on: empty, atEnd: false)
            }
        }
    }
    func moveBlock(_ id: AnyHashable, after predecessor: AnyHashable?) {
        guard let value = block(id), predecessor != id, predecessor == nil || block(predecessor!) != nil,
              let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        let before = index > 0 ? blocks[index - 1] : nil
        let after = index + 1 < blocks.count ? blocks[index + 1] : nil
        guard before?.id != predecessor else { return }
        command(.other) {
            remove(id)
            var destination = predecessor
            if let before, let after, let lhs = string(before.id), let rhs = string(after.id) {
                let separator = lhs.isEmpty || lhs.hasSuffix("\n") || rhs.isEmpty ? "" : "\n"
                insert(separator + rhs, in: before.id, at: lhs.utf16.count)
                remove(after.id)
                if destination == after.id { destination = before.id }
            }
            insert(value, after: destination)
            if case .text = value {
                let placed = blocks.firstIndex { $0.id == id }!
                let previous = placed > 0 ? blocks[placed - 1] : nil
                let next = placed + 1 < blocks.count ? blocks[placed + 1] : nil
                if let previous, let lhs = string(previous.id), let current = string(id) {
                    let separator = lhs.isEmpty || lhs.hasSuffix("\n") || current.isEmpty ? "" : "\n"
                    insert(lhs + separator, in: id, at: 0); remove(previous.id)
                }
                if let next, let rhs = string(next.id), let current = string(id) {
                    let separator = current.isEmpty || current.hasSuffix("\n") || rhs.isEmpty ? "" : "\n"
                    insert(separator + rhs, in: id, at: current.utf16.count); remove(next.id)
                }
            }
            place(.blocks(anchor: id, head: id))
        }
    }
    func replaceCard(_ id: AnyHashable, with value: Material.Block) {
        guard let index = blocks.firstIndex(where: { $0.id == id }), value.id == id || block(value.id) == nil else { return }
        let previous = index == 0 ? nil : blocks[index - 1].id
        command(.other) {
            remove(id); insert(value, after: previous)
            place(.blocks(anchor: value.id, head: value.id))
        }
    }
    func commitReference(_ reference: Reference, name: String? = nil) {
        guard let markdown = Reference.Link.markdown(for: reference, name: name) else { return }
        commitText(markdown)
    }
    func commitText(_ text: String) {
        guard let trigger, case .text(trigger.id, _, let head) = position else { return }
        command(.other) { replace(in: trigger.id, range: trigger.offset..<head, with: text); setTrigger(nil) }
    }
    func commitTask(_ text: String, completed: Bool) {
        guard let trigger, case .text(trigger.id, _, let head) = position else { return }
        command(.other) {
            delete(in: trigger.id, range: trigger.offset..<head)
            place(.text(id: trigger.id, anchor: trigger.offset, head: trigger.offset))
            insertCard(.task(UUID(), text, completed)); setTrigger(nil)
        }
    }
}
