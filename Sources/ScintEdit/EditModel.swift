import Foundation
import ScintRuntime


/// Which block holds the keyboard and whether it is being typed into, plus the menu the
/// triggers drive. Everything it knows about a block comes from the document; everything
/// it knows about a surface arrives as an `EditEvent`. It reaches into neither.
@MainActor @Observable final class EditModel {
    let document: Reference
    let menu: MenuController

    var onFocus: () -> Void = {}
    private(set) var focused: AnyHashable?
    private(set) var editing = false

    /// Which end the caret enters the focused block by, until its surface has taken it.
    private(set) var entry: EditEdge?

    init(document: Reference) {
        self.document = document
        self.menu = MenuController(
            items: EditSurface.items,
            search: { query, kind in MainActor.assumeIsolated { EditSurface.search(query, kind: kind) } }
        )
    }

    var blocks: [Document.Block] { Document.with(document, { $0.blocks }) ?? [] }

    func isSelected(_ id: AnyHashable) -> Bool { focused == id && !editing }

    /// Side effects live here, not in `init`: SwiftUI re-evaluates a `@State` initial
    /// value on every view init, and touching the store there feeds the observation
    /// graph back into itself.
    func prepare() {
        EditBlocks.ensureTrailingText(document)
        guard focused == nil, let id = firstText else { return }
        land(.init(id: id, edge: .end))
    }

    /// A block was clicked. What that meant to the block is the block's business; all
    /// the canvas reports is that focus belongs there now.
    func focus(_ id: AnyHashable) {
        took(id)
        entry = nil
    }

    // MARK: Events

    /// Returns whether the canvas did anything, so a surface that offered a key can keep
    /// it when the answer is no — at the first block, Up is still Up.
    @discardableResult
    func handle(_ event: EditEvent, from id: AnyHashable) -> Bool {
        switch event {
            case .focused:
                guard block(id) != nil else { return false }
                onFocus()
                took(id)
                // The surface owns its caret from here.
                entry = nil
                return true

            case .changed(let text):
                took(id)
                guard let index = index(of: id) else { return false }
                return EditBlocks.setText(document, at: index, to: text)

            case .trigger(let trigger):
                sync(trigger)
                return true

            case .newline:
                if menu.isOpen { commitMenu() } else { insertBelow(id) }
                return true

            case .deleteAtStart:
                closeMenu()
                return remove(id)

            case .escape:
                if menu.isOpen { closeMenu() } else { editing = false }
                return true

            case .exit(let edge):
                guard !menu.isOpen else {
                    menu.moveSelection(edge == .start ? -1 : 1)
                    return true
                }
                return move(edge, from: id)
        }
    }

    // MARK: Menu

    /// A form panel holds the keyboard while it is up, so closing hands it back.
    /// Nothing re-asserts focus here: the focused surface reclaims the keyboard on the
    /// next update, which is the same pass that tears the panel down.
    func closeMenu() {
        guard menu.isOpen else { return }
        menu.close()
    }

    func commitMenu() {
        // No outcome means the menu moved on to a form.
        guard let outcome = menu.commit() else { return }
        let range = outcome.replacementRange
        let stamped = EditSurface.blocks(for: outcome)
        menu.close()
        insert(stamped, replacing: range)
    }

    /// A form owns the panel and the keyboard once it opens, so typing never reopens the
    /// list behind it.
    private func sync(_ trigger: EditTrigger?) {
        if case .create = menu.kind { return }
        guard let trigger else { return closeMenu() }
        menu.open(
            kind: trigger.symbol == "/" ? .fixed : .dynamic,
            query: trigger.query,
            target: document,
            replacementRange: trigger.range,
            anchorRect: trigger.anchor
        )
    }

    // MARK: Structure

    /// Return on a block with no text surface of its own opens a new paragraph directly
    /// below it. A text surface keeps its own Return: that newline is part of its text.
    private func insertBelow(_ id: AnyHashable) {
        guard let index = index(of: id), !isText(id) else { return }
        land(.init(id: EditBlocks.insertText(document, at: index + 1), edge: .start))
    }

    /// Delete at the start of a text block merges it backwards. With nothing to merge
    /// into — a component sits above it — an empty block goes away and a block with text
    /// in it only hands focus back. On a component it takes the block out.
    private func remove(_ id: AnyHashable) -> Bool {
        guard let index = index(of: id) else { return false }
        guard isText(id) else {
            let landing = EditBlocks.remove(document, ids: [id])
            EditBlocks.ensureTrailingText(document)
            land(landing)
            return true
        }
        if let landing = EditBlocks.mergeBackward(document, at: index) { land(landing); return true }
        guard index > blocks.startIndex else { return false }
        guard isEmpty(id) else { land(.init(id: blocks[index - 1].id, edge: .end)); return true }
        // No trailing text is restored: deleting it is what was asked for, and Return on
        // the block above makes another.
        land(EditBlocks.remove(document, ids: [id]))
        return true
    }

    private func move(_ edge: EditEdge, from id: AnyHashable) -> Bool {
        let blocks = self.blocks
        let delta = edge == .start ? -1 : 1
        guard let index = blocks.firstIndex(where: { $0.id == id }),
              blocks.indices.contains(index + delta)
                else { return false }
        land(.init(id: blocks[index + delta].id, edge: delta < 0 ? .end : .start))
        return true
    }

    /// Text-only stamps splice into the block the trigger came from; anything else splits
    /// it and lands on the text that follows.
    private func insert(_ stamped: [Document.Block], replacing range: NSRange) {
        guard let id = focused, let origin = index(of: id), !stamped.isEmpty else { return }

        if let text = textValue(of: stamped) {
            return land(EditBlocks.spliceText(document, at: origin, replacing: range, with: text))
        }

        guard let last = EditBlocks.splice(document, at: origin, replacing: range, with: stamped),
              let index = index(of: last)
                else { return land(nil) }

        // The splice leaves whatever followed the trigger in a block of its own.
        let next = index + 1
        let landing = blocks.indices.contains(next) && blocks[next].isText
        ? blocks[next].id
        : EditBlocks.insertText(document, at: next)
        land(.init(id: landing, edge: .start))
    }

    // MARK: Focus

    private func took(_ id: AnyHashable) {
        if focused != id { focused = id }
        let typing = isText(id)
        if editing != typing { editing = typing }
    }

    /// Names the block that should hold the keyboard and which end its caret comes in
    /// by. The canvas mirrors that into focus; nothing here touches a surface. A lost
    /// landing falls back to the first place you can type.
    private func land(_ landing: EditBlocks.Landing?) {
        guard let landing else {
            guard let id = firstText else { return }
            return land(.init(id: id, edge: .end))
        }
        took(landing.id)
        entry = landing.edge
    }

    // MARK: Lookup

    private func block(_ id: AnyHashable) -> Document.Block? { blocks.first { $0.id == id } }

    private func index(of id: AnyHashable) -> Int? { blocks.firstIndex { $0.id == id } }

    private func isText(_ id: AnyHashable) -> Bool { block(id)?.isText ?? false }

    private func isEmpty(_ id: AnyHashable) -> Bool {
        guard case .text(_, let text)? = block(id) else { return false }
        return text.isEmpty
    }

    private var firstText: AnyHashable? { blocks.first(where: \.isText)?.id }

    private func textValue(of blocks: [Document.Block]) -> String? {
        var value = ""
        for block in blocks {
            guard case .text(_, let text) = block else { return nil }
            value += text
        }
        return value
    }
}


extension Document.Block {
    var isText: Bool {
        if case .text = self { return true }
        return false
    }
}
