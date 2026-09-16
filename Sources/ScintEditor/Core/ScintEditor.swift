import Foundation
import Observation


@MainActor protocol TextRendering: AnyObject {
    func replace(_ range: Range<Int>, with text: String)
    func select(anchor: Int, head: Int)
    func clearSelection()
}

@MainActor @Observable final class ScintEditor {
    let material: Reference
    private(set) var position: Position

    enum Position: Equatable {
        case empty
        case text(id: AnyHashable, anchor: Int, head: Int)
        case blocks(anchor: AnyHashable, head: AnyHashable)
        var id: AnyHashable? {
            switch self { case .empty: nil; case .text(let id, _, _): id; case .blocks(_, let head): head }
        }
    }

    enum Direction { case up, down }
    enum Link: Equatable { case reference(Reference), url(URL) }

    struct Trigger: Equatable { let id: AnyHashable; let offset: Int; let character: String }
    private(set) var trigger: Trigger?
    var onOpenLink: (Link) -> Void = { _ in }
    let undoManager = UndoManager()
    var undoStack: [Group] = []
    var redoStack: [Group] = []

    @ObservationIgnored var openGroup: Group?
    @ObservationIgnored var groupDepth = 0
    @ObservationIgnored var registrationSuspended = false
    @ObservationIgnored var clock: () -> TimeInterval = { Date.timeIntervalSinceReferenceDate }
    @ObservationIgnored var lastEditTime: TimeInterval = -.infinity
    @ObservationIgnored var coalescingPosition: Position?
    @ObservationIgnored var positionIndex: Int
    @ObservationIgnored private var renderers: [AnyHashable: WeakRenderer] = [:]

    private final class WeakRenderer {
        weak var value: (any TextRendering)?
        init(_ value: any TextRendering) { self.value = value }
    }

    init(_ material: Reference) {
        self.material = material
        let blocks = Material.with(material, { $0.blocks }) ?? []
        guard let last = blocks.last
        else { position = .empty; positionIndex = 0; undoManager.groupsByEvent = false; return }
        positionIndex = blocks.count - 1
        if case .text(_, let string) = last { position = .text(id: last.id, anchor: string.utf16.count, head: string.utf16.count) }
        else { position = .blocks(anchor: last.id, head: last.id) }
        undoManager.groupsByEvent = false
    }

    var blocks: [Material.Block] { Material.with(material, { $0.blocks }) ?? [] }

    func block(_ id: AnyHashable) -> Material.Block? { blocks.first { $0.id == id } }

    func string(_ id: AnyHashable) -> String? { guard case .text(_, let string)? = block(id) else { return nil }; return string }

    static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    static func snap(_ offset: Int, in text: String) -> Int {
        let source = text as NSString
        let offset = min(max(0, offset), source.length)
        return offset == source.length ? offset : source.rangeOfComposedCharacterSequence(at: offset).location
    }

    @discardableResult func insert(_ text: String, in id: AnyHashable, at offset: Int) -> Bool {
        guard case .text(let uuid, let value)? = block(id), !text.isEmpty,
              (0...value.utf16.count).contains(offset) else { return false }
        let text = Self.normalized(text)
        let next = (value as NSString).replacingCharacters(in: NSRange(location: offset, length: 0), with: text)
        guard Material.update(material, { material -> Bool in
            guard let index = material.blocks.firstIndex(where: { $0.id == id }) else { return false }
            material.update(.text(uuid, next), at: index); return true
        }) == true else { return false }
        renderers[id]?.value?.replace(offset..<offset, with: text)
        record(.insertText(id: id, offset: offset, text: text))
        return true
    }

    @discardableResult func delete(in id: AnyHashable, range: Range<Int>) -> Bool {
        guard case .text(let uuid, let value)? = block(id), !range.isEmpty,
              range.lowerBound >= 0, range.upperBound <= value.utf16.count else { return false }
        let source = value as NSString
        let deleted = source.substring(with: NSRange(range))
        let next = source.replacingCharacters(in: NSRange(range), with: "")
        guard Material.update(material, { material -> Bool in
            guard let index = material.blocks.firstIndex(where: { $0.id == id }) else { return false }
            material.update(.text(uuid, next), at: index); return true
        }) == true else { return false }
        renderers[id]?.value?.replace(range, with: "")
        record(.deleteText(id: id, offset: range.lowerBound, text: deleted))
        return true
    }

    @discardableResult func insert(_ block: Material.Block, after previous: AnyHashable?) -> Bool {
        let wrote = Material.update(material) { material -> Bool in
            guard !material.blocks.contains(where: { $0.id == block.id }) else { return false }
            let index: Int
            if let previous {
                guard let before = material.blocks.firstIndex(where: { $0.id == previous }) else { return false }
                index = before + 1
            } else { index = 0 }
            let count = material.blocks.count
            material.insert(block, at: index)
            return material.blocks.count == count + 1
        } == true
        if wrote { record(.insertBlock(block, after: previous)) }
        return wrote
    }

    @discardableResult func remove(_ id: AnyHashable) -> Bool {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return false }
        let block = blocks[index], previous = index > 0 ? blocks[index - 1].id : nil
        guard Material.update(material, { material -> Bool in
            guard let index = material.blocks.firstIndex(where: { $0.id == id }) else { return false }
            material.delete(at: index); return true
        }) == true else { return false }
        record(.removeBlock(block, after: previous)); return true
    }

    func attach(_ renderer: any TextRendering, to id: AnyHashable) {
        renderers[id] = WeakRenderer(renderer)
        if case .text(id, let anchor, let head) = position { renderer.select(anchor: anchor, head: head) }
    }

    func detach(from id: AnyHashable) { renderers[id] = nil }

    func place(_ proposed: Position) {
        let next: Position
        switch proposed {
        case .empty:
            guard blocks.isEmpty else { return }; next = .empty
        case .text(let id, let anchor, let head):
            guard let text = string(id), (0...text.utf16.count).contains(anchor),
                  (0...text.utf16.count).contains(head) else { return }
            next = .text(id: id, anchor: Self.snap(anchor, in: text), head: Self.snap(head, in: text))
        case .blocks(let anchor, let head):
            guard block(anchor) != nil, block(head) != nil else { return }; next = proposed
        }
        guard next != position else { return }
        if groupDepth == 0 { coalescingPosition = nil }
        let old = position
        position = next
        positionIndex = blocks.firstIndex { $0.id == next.id } ?? positionIndex
        validateTrigger()
        if case .text(let id, _, _) = old, id != next.id || !isTextPosition {
            renderers[id]?.value?.clearSelection()
        }
        if case .text(let id, let anchor, let head) = next { renderers[id]?.value?.select(anchor: anchor, head: head) }
    }

    var isTextPosition: Bool { if case .text = position { true } else { false } }

    func setTrigger(_ trigger: Trigger?) { self.trigger = trigger }

    func validateTrigger() {
        guard let trigger else { return }
        guard case .text(trigger.id, _, let head) = position, head > trigger.offset,
              let text = string(trigger.id), head <= text.utf16.count,
              !(text as NSString).substring(with: NSRange(location: trigger.offset, length: head - trigger.offset)).contains("\n")
        else { self.trigger = nil; return }
    }

    var query: String? {
        guard let trigger, case .text(trigger.id, _, let head) = position, let text = string(trigger.id),
              head > trigger.offset, head <= text.utf16.count else { return nil }
        return (text as NSString).substring(with: NSRange(location: trigger.offset + 1, length: head - trigger.offset - 1))
    }

    func linkRange(in id: AnyHashable, containing offset: Int) -> (range: Range<Int>, link: Link)? {
        guard let text = string(id) else { return nil }
        let source = text as NSString
        guard let match = Markdown.scan(text).links.first(where: { NSLocationInRange(offset, $0.range) }) else { return nil }
        let url = source.substring(with: match.url)
        if let reference = Reference.Link.reference(in: url) { return (match.range.location..<NSMaxRange(match.range), .reference(reference)) }
        guard let url = URL(string: url) else { return nil }
        return (match.range.location..<NSMaxRange(match.range), .url(url))
    }

    var selectedLink: Link? {
        switch position {
        case .empty: return nil
        case .text(let id, let anchor, let head):
            guard anchor != head, let match = linkRange(in: id, containing: min(anchor, head)),
                  match.range == min(anchor, head)..<max(anchor, head) else { return nil }; return match.link
        case .blocks(let anchor, let head):
            guard anchor == head else { return nil }
            switch block(head) {
            case .artifact(let ref), .command(let ref), .material(let ref): return .reference(ref)
            default: return nil
            }
        }
    }

    var selectedReference: Reference? { if case .reference(let ref) = selectedLink { ref } else { nil } }

    func open(_ link: Link) { onOpenLink(link) }
}
