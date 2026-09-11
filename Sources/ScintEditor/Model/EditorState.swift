import SwiftUI


@Observable @MainActor final class EditorState {
    private(set) var material: DocumentModel
    private(set) var menu: MenuController
    private(set) var themeRevision = 0
    let themer = EditorThemer()

    var selection: EditorSelection = .none
    var caretRect: CGRect = .zero
    var blockFrames: [AnyHashable: CGRect] = [:]

    init(material ref: Reference, menuItems: [MenuItem], search: @escaping (String, MenuKind) -> [MenuItem]) {
        self.material = DocumentModel(ref)
        self.menu = MenuController(items: menuItems, search: search)
    }

    func setTheme(_ theme: Theme) {
        themer.theme = theme
        themeRevision &+= 1
    }

    func focusGained(id: AnyHashable) {
        guard selection.id != id, material.block(id: id) != nil else { return }
        enterEditing(id)
    }

    func editBlock(id: AnyHashable, anchor: CGRect) {
        guard let block = material.block(id: id),
              let form = MenuSurface.form(for: block)
        else { return }
        selectBlock(id)
        menu.edit(form: form.0, values: form.1, target: id, anchorRect: anchor)
    }

    func setBlockFrames(_ frames: [AnyHashable: CGRect]) {
        if blockFrames != frames { blockFrames = frames }
    }

    func writeRun(ids: [AnyHashable], text: String, selection range: NSRange) {
        let lines = text.components(separatedBy: "\n")

        guard lines.count != ids.count else {
            for (id, line) in zip(ids, lines) {
                guard case .text(_, let current)? = material.block(id: id), current != line else { continue }
                material.write(line, to: id)
            }
            settle(ids, at: range)
            return
        }

        let resulting = material.replaceRun(ids, with: lines)
        guard !resulting.isEmpty else { return }
        settle(resulting, at: range)
        renumberLists()
    }

    private func settle(_ ids: [AnyHashable], at range: NSRange) {
        let run = TextRun(ids.compactMap { material.block(id: $0) })
        if let landing = run.locate(range.location) {
            selection = .caret(landing.id, NSRange(location: landing.range.location, length: range.length))
        }
        openMenuIfTriggered()
    }

    func setRunCaret(ids: [AnyHashable], selection range: NSRange) {
        if range.length == 0 { ReferenceSelection.shared.selected = nil }

        let run = TextRun(ids.compactMap { material.block(id: $0) })
        guard let landing = run.locate(range.location) else { return }

        if range.length > 0,
           case .text(_, let text)? = material.block(id: landing.id),
           componentRanges(in: text as NSString).contains(landing.range) {
            selectComponent(landing.range, in: landing.id, text: text as NSString)
            return
        }

        selection = .caret(landing.id, NSRange(location: landing.range.location, length: range.length))
    }

    func focusGained(run ids: [AnyHashable]) {
        guard let first = ids.first, !ids.contains(where: { $0 == selection.id }) else { return }
        enterEditing(first, caret: NSRange(location: 0, length: 0))
    }

    func handleRunInput(ids: [AnyHashable], _ selector: Selector, selection range: NSRange, textLength: Int) -> Bool {
        if menu.isOpen {
            let result = menu.handleInput(selector)
            if let outcome = result.outcome { acceptMenuOutcome(outcome) }
            return result.handled
        }

        let atStart = range.length == 0 && range.location == 0
        let atEnd = range.length == 0 && range.location == textLength

        switch selector {
            case #selector(NSResponder.deleteBackward(_:)) where atStart:
                return step(from: ids.first, -1)
            case #selector(NSResponder.moveUp(_:)) where atStart,
                 #selector(NSResponder.moveLeft(_:)) where atStart:
                return step(from: ids.first, -1)
            case #selector(NSResponder.moveDown(_:)) where atEnd,
                 #selector(NSResponder.moveRight(_:)) where atEnd:
                return step(from: ids.last, 1)
            case #selector(NSResponder.selectAll(_:)) where range.length == textLength:
                return selectAllBlocks()
            case #selector(NSResponder.cancelOperation(_:)):
                return endEditing()
            case #selector(NSResponder.insertTab(_:)):
                return nest(by: 1)
            case #selector(NSResponder.insertBacktab(_:)):
                return nest(by: -1)
            default:
                return false
        }
    }


    func updateCaretRect(id: AnyHashable, rect: CGRect) {
        guard selection.editing == id, caretRect != rect else { return }
        caretRect = rect
        if menu.isOpen { menu.anchorRect = rect }
    }

    func commitMenuSelection() {
        guard let outcome = menu.commit() else { return }
        acceptMenuOutcome(outcome)
    }

    func handleInput(_ selector: Selector, selection range: NSRange, textLength: Int) -> Bool {
        if menu.isOpen {
            let result = menu.handleInput(selector)
            if let outcome = result.outcome { acceptMenuOutcome(outcome) }
            return result.handled
        }

        for command in commands(for: selector, selection: range, textLength: textLength) {
            if apply(command, selection: range) { return true }
        }
        return false
    }

    private func commands(for selector: Selector, selection range: NSRange, textLength: Int) -> [EditorCommand] {
        let editing = selection.isEditing
        let atStart = range.length == 0 && range.location == 0
        let atEnd = range.length == 0 && range.location == textLength

        switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                return [.insertBlockAfter]
            case #selector(NSResponder.cancelOperation(_:)):
                return [.dismiss]
            case #selector(NSResponder.deleteBackward(_:)):
                if editing, atStart == false, let component = component(where: { NSMaxRange($0) == range.location }) {
                    return [.selectReference(component)]
                }
                return [.deleteBlock]
            case #selector(NSResponder.moveUp(_:)):
                return [.step(-1)]
            case #selector(NSResponder.moveDown(_:)):
                return [.step(1)]
            case #selector(NSResponder.moveLeft(_:)):
                if range.length == 0, let component = component(where: { NSMaxRange($0) == range.location }) {
                    return [.selectReference(component)]
                }
                return atStart ? [.step(-1)] : []
            case #selector(NSResponder.moveRight(_:)):
                if range.length == 0, let component = component(where: { $0.location == range.location }) {
                    return [.selectReference(component)]
                }
                return atEnd ? [.step(1)] : []
            case #selector(NSResponder.selectAll(_:)):
                return editing && range.length < textLength ? [] : [.selectAllBlocks]
            case #selector(NSResponder.insertTab(_:)):
                return !editing || atEnd ? [.nest(1), .step(1)] : [.nest(1)]
            case #selector(NSResponder.insertBacktab(_:)):
                return [.nest(-1)]
            default:
                return []
        }
    }

    private func editingText() -> NSString? {
        guard let editing = selection.editing,
              case .text(_, let text)? = material.block(id: editing)
        else { return nil }
        return text as NSString
    }

    private func apply(_ command: EditorCommand, selection range: NSRange) -> Bool {
        switch command {
            case .insertBlockAfter: return insertBlockAfter()
            case .deleteBlock: return deleteBlock()
            case .nest(let levels): return nest(by: levels)
            case .step(let offset): return step(from: selection.id, offset)
            case .selectReference(let component): return selectReference(component)
            case .dismiss: return endEditing()
            case .selectAllBlocks: return selectAllBlocks()
        }
    }

    @discardableResult
    func beginEditingFromMaterialClick(at point: CGPoint) -> Bool {
        if menu.isOpen { menu.close() }
        let blocks = material.blocks
        guard !blocks.isEmpty else { return insertText(at: 0) }

        let framed = blocks.compactMap { block -> (Material.Block, CGRect)? in
            guard let frame = blockFrames[block.id] else { return nil }
            return (block, frame)
        }.sorted { $0.1.minY < $1.1.minY }

        if let hit = framed.first(where: { $0.1.contains(point) })
            ?? framed.last(where: { point.y >= $0.1.maxY }),
           let index = material.index(for: hit.0.id) {
            return beginEditing(near: hit.0, insertingAfter: index)
        }

        if let first = framed.first(where: { if case .text = $0.0 { true } else { false } })?.0,
           let index = material.index(for: first.id) {
            return beginEditing(near: first, insertingAfter: index, atStart: true)
        }

        return insertText(at: 0)
    }

    private func insertBlockAfter() -> Bool {
        guard let id = selection.id,
              let index = material.index(for: id),
              let block = material.block(id: id)
        else { return false }
        if case .text = block { return false }
        return insertText(at: index + 1)
    }


    private func deleteBlock() -> Bool {
        let ids = selection.ids
        guard !ids.isEmpty else { return false }
        for id in ids { blockFrames[id] = nil }
        let landing = material.delete(ids)

        guard let landing, material.block(id: landing) != nil else {
            return insertText(at: 0)
        }

        enterEditing(landing)
        return true
    }

    private func nest(by levels: Int) -> Bool {
        guard let editing = selection.editing,
              case .text(_, let text)? = material.block(id: editing)
        else { return false }

        let nested = Markdown.indented(text, by: levels)
        guard nested != text else { return false }

        let shift = (nested as NSString).length - (text as NSString).length
        let caret = selection.range ?? NSRange(location: 0, length: 0)
        material.write(nested, to: editing, structural: true)
        selection = .caret(editing, NSRange(location: max(0, caret.location + shift), length: caret.length))
        renumberLists()
        return true
    }

    private func componentRanges(in text: NSString) -> [NSRange] {
        Markdown.scan(text as String).links.compactMap { link in
            guard Reference.Link.reference(in: text.substring(with: link.url)) != nil else { return nil }
            return link.range
        }
    }

    private func component(where match: (NSRange) -> Bool) -> NSRange? {
        guard let text = editingText() else { return nil }
        return componentRanges(in: text).first(where: match)
    }

    private func soleComponent(in text: String) -> NSRange? {
        let source = text as NSString
        let ranges = componentRanges(in: source)
        guard ranges.count == 1, ranges[0].location == 0, NSMaxRange(ranges[0]) == source.length
        else { return nil }
        return ranges[0]
    }

    @discardableResult
    private func selectReference(_ range: NSRange) -> Bool {
        guard let editing = selection.editing, let text = editingText() else { return false }
        selectComponent(range, in: editing, text: text)
        return true
    }

    private func selectComponent(_ range: NSRange, in id: AnyHashable, text: NSString) {
        selection = .caret(id, range)
        guard let link = Markdown.scan(text as String).links.first(where: { $0.range == range })
        else { return }
        ReferenceSelection.shared.selected = Reference.Link.reference(in: text.substring(with: link.url))
    }

    private func step(from id: AnyHashable?, _ offset: Int) -> Bool {
        let blocks = material.blocks

        if case .blocks(let ids) = selection {
            let ordered = blocks.filter { ids.contains($0.id) }
            guard let edge = offset < 0 ? ordered.first : ordered.last else { return false }
            selection = .block(edge.id)
            return true
        }

        guard let id,
              let index = blocks.firstIndex(where: { $0.id == id }),
              blocks.indices.contains(index + offset)
        else { return false }

        let target = blocks[index + offset]

        if case .text(_, let text) = target, let component = soleComponent(in: text) {
            selectComponent(component, in: target.id, text: text as NSString)
            return true
        }

        enterEditing(target.id, caret: offset < 0 ? nil : NSRange(location: 0, length: 0))
        return true
    }


    private func acceptMenuOutcome(_ outcome: MenuOutcome) {
        guard let result = MenuSurface.apply(outcome, to: material) else { return }
        menu.close()
        if let caret = result.caret { enterEditing(result.id, caret: caret) }
        else if outcome.isInserting, let index = material.index(for: result.id) { ensureText(after: index) }
        else { selectBlock(result.id) }
    }

    private func renumberLists() {
        let blocks = material.blocks
        let lines = blocks.map { block -> String in
            if case .text(_, let text) = block { return text }
            return ""
        }

        guard lines.contains(where: { $0.drop(while: \.isWhitespace).first?.isNumber == true })
        else { return }

        for (block, line) in zip(blocks, Markdown.renumbered(lines)) {
            guard case .text(let id, let text) = block, text != line else { continue }
            material.write(line, to: id)
        }
    }

    private func ensureText(after index: Int) {
        let blocks = material.blocks
        let next = index + 1

        if blocks.indices.contains(next), case .text = blocks[next] {
            enterEditing(blocks[next].id, caret: NSRange(location: 0, length: 0))
        } else {
            _ = insertText(at: next)
        }
    }

    private func insertText(at index: Int) -> Bool {
        guard let id = material.insertText(at: index) else { return false }
        enterEditing(id, caret: NSRange(location: 0, length: 0))
        return true
    }

    private func beginEditing(near block: Material.Block, insertingAfter index: Int, atStart: Bool = false) -> Bool {
        if case .text(_, let text) = block {
            enterEditing(block.id, caret: NSRange(location: atStart ? 0 : (text as NSString).length, length: 0))
        } else {
            ensureText(after: index)
        }
        return true
    }

    private func enterEditing(_ id: AnyHashable, caret: NSRange? = nil) {
        guard case .text(_, let text)? = material.block(id: id) else {
            selection = .block(id)
            return
        }
        selection = .caret(id, caret ?? NSRange(location: (text as NSString).length, length: 0))
    }

    private func selectBlock(_ id: AnyHashable) {
        selection = .block(id)
    }

    private func selectAllBlocks() -> Bool {
        let ids = Set(material.blocks.map(\.id))
        guard !ids.isEmpty else { return false }
        ReferenceSelection.shared.selected = nil
        selection = .blocks(ids)
        return true
    }

    func prepare() {
        material.inlineReferenceBlocks()
        if let trailing = ensureTrailingText() { enterEditing(trailing) }
    }

    @discardableResult
    func ensureTrailingText() -> AnyHashable? {
        let blocks = material.blocks
        if case .text(let id, _)? = blocks.last { return id }
        return material.insertText(at: blocks.endIndex)
    }

    func deactivate(pruning: Bool = true) {
        if pruning { pruneTrailingEmptyText() }
        ReferenceSelection.shared.selected = nil
        selection = .none
    }

    @discardableResult
    private func endEditing() -> Bool {
        if case .blocks = selection {
            ReferenceSelection.shared.selected = nil
            selection = .none
            return true
        }
        guard let editing = selection.editing else { return false }
        let landing = pruneTrailingEmptyText()
        let surviving = material.block(id: editing) == nil ? landing : editing
        selection = surviving.map { EditorSelection.block($0) } ?? .none
        return true
    }

    @discardableResult
    private func pruneTrailingEmptyText(excluding retainedID: AnyHashable? = nil) -> AnyHashable? {
        var landing: AnyHashable?

        while let trailing = Material.with(material.ref, { $0.blocks.last }) ?? nil,
              trailing.id != retainedID,
              case .text(_, let text) = trailing,
              text.isEmpty {
            blockFrames[trailing.id] = nil
            let next = material.delete([trailing.id])
            if selection.id == trailing.id { selection = next.map { EditorSelection.block($0) } ?? .none }
            landing = next
        }

        return landing
    }

    private func openMenuIfTriggered() {
        guard !menu.isOpen,
              case .caret(let editing, let range) = selection,
              case .text(_, let text)? = material.block(id: editing)
        else { return }

        let source = text as NSString
        let cursor = range.location
        guard cursor > 0, cursor <= source.length else { return }

        let index = cursor - 1
        let character = source.substring(with: NSRange(location: index, length: 1))
        guard character == "/" || character == "@" else { return }

        if index > 0 {
            let previous = source.substring(with: NSRange(location: index - 1, length: 1))
            guard previous == " " || previous == "\t" || previous == "\n" else { return }
        }

        menu.open(
            kind: character == "/" ? .fixed : .dynamic,
            query: "",
            target: editing,
            replacementRange: NSRange(location: index, length: 1),
            anchorRect: caretRect
        )
    }
}
