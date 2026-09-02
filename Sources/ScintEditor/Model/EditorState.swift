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
        guard let block = material.block(id: id) else { return }
        if case .text = block { enterEditing(id) } else { selectBlock(id) }
    }

    func editBlock(id: AnyHashable, anchor: CGRect) {
        guard let block = material.block(id: id),
              let form = MenuSurface.form(for: block)
        else { return }
        selectBlock(id)
        menu.edit(form: form.0, values: form.1, target: id, anchorRect: anchor)
    }

    func setCaret(id: AnyHashable, selection range: NSRange) {
        if range.length == 0 { ReferenceSelection.shared.selected = nil }
        selection = .caret(id, range)
    }

    func write(id: AnyHashable, text: String, selection range: NSRange) {
        selection = .caret(id, range)

        if text.contains("\n"), !Markdown.holdsMultipleLines(text) {
            let lines = text.components(separatedBy: "\n")
            if let result = material.replaceText(at: id, with: lines) {
                enterEditing(result.id, caret: result.caret)
                renumberLists()
                return
            }
        }

        if material.write(text, to: id) {
            renumberLists()
            openMenuIfTriggered()
        }
    }

    func updateBlockFrame(id: AnyHashable, frame: CGRect) {
        if blockFrames[id] != frame { blockFrames[id] = frame }
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
                return editing ? [.splitBlock] : [.insertBlockAfter]
            case #selector(NSResponder.cancelOperation(_:)):
                return [.dismiss]
            case #selector(NSResponder.deleteBackward(_:)):
                if editing, atStart == false, let component = componentEnding(at: range) {
                    return [.selectReference(component)]
                }
                return editing ? [.mergeBackward] : [.deleteBlock]
            case #selector(NSResponder.moveUp(_:)):
                return atFirstLine(range) ? [.step(-1)] : []
            case #selector(NSResponder.moveDown(_:)):
                return atLastLine(range) ? [.step(1)] : []
            case #selector(NSResponder.moveLeft(_:)):
                if range.length == 0, let component = componentEnding(at: range) {
                    return [.selectReference(component)]
                }
                return atStart ? [.step(-1)] : []
            case #selector(NSResponder.moveRight(_:)):
                if range.length == 0, let component = componentStarting(at: range) {
                    return [.selectReference(component)]
                }
                return atEnd ? [.step(1)] : []
            case #selector(NSResponder.insertTab(_:)):
                return !editing || atEnd ? [.nest(1), .step(1)] : [.nest(1)]
            case #selector(NSResponder.insertBacktab(_:)):
                return [.nest(-1)]
            default:
                return []
        }
    }

    private func atFirstLine(_ range: NSRange) -> Bool {
        guard let text = editingText() else { return true }
        let location = min(range.location, text.length)
        return text.lineRange(for: NSRange(location: location, length: 0)).location == 0
    }

    private func atLastLine(_ range: NSRange) -> Bool {
        guard let text = editingText() else { return true }
        let location = min(range.location, text.length)
        return NSMaxRange(text.lineRange(for: NSRange(location: location, length: 0))) >= text.length
    }

    private func editingText() -> NSString? {
        guard let editing = selection.editing,
              case .text(_, let text)? = material.block(id: editing)
        else { return nil }
        return text as NSString
    }

    private func apply(_ command: EditorCommand, selection range: NSRange) -> Bool {
        switch command {
            case .splitBlock: return splitBlock(range)
            case .insertBlockAfter: return insertBlockAfter()
            case .mergeBackward: return mergeBackward(range)
            case .deleteBlock: return deleteBlock()
            case .nest(let levels): return nest(by: levels)
            case .step(let offset): return step(offset)
            case .selectReference(let component): return selectReference(component)
            case .dismiss: return endEditing()
        }
    }

    @discardableResult
    func beginEditingFromMaterialClick(at point: CGPoint) -> Bool {
        if menu.isOpen { menu.close() }
        let blocks = Material.with(material.ref, { $0.blocks }) ?? []
        guard !blocks.isEmpty else { return insertText(at: 0) }

        let framed = blocks.enumerated().compactMap { index, block -> (Int, Material.Block, CGRect)? in
            guard let frame = blockFrames[block.id] else { return nil }
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

    private func splitBlock(_ range: NSRange) -> Bool {
        guard let editing = selection.editing,
              case .text(_, let text)? = material.block(id: editing)
        else { return false }
        if Markdown.isEmptyItem(text) {
            let outdented = Markdown.indented(text, by: -1)
            let next = outdented == text ? "" : outdented
            material.write(next, to: editing, structural: true)
            selection = .caret(editing, NSRange(location: (next as NSString).length, length: 0))
            renumberLists()
            return true
        }

        let start = Markdown.editBoundary(range.location, in: text)
        let end = Markdown.editBoundary(NSMaxRange(range), in: text)
        let safe = NSRange(location: start, length: max(0, end - start))

        let prefix = safe.location >= Markdown.prefixLength(of: text)
            ? Markdown.continuation(for: text) ?? ""
            : ""

        guard let split = material.splitText(at: editing, range: safe, prefix: prefix) else { return false }
        enterEditing(split.id, caret: split.caret)
        renumberLists()
        return true
    }

    private func insertBlockAfter() -> Bool {
        guard let id = selection.id,
              let index = material.index(for: id),
              let block = material.block(id: id)
        else { return false }
        if case .text = block { return false }
        return insertText(at: index + 1)
    }

    private func mergeBackward(_ range: NSRange) -> Bool {
        guard let editing = selection.editing,
              range.location == 0,
              range.length == 0,
              let index = material.index(for: editing),
              index > 0
        else { return false }

        if let merged = material.mergeText(at: editing) {
            enterEditing(merged.id, caret: merged.caret)
            renumberLists()
            return true
        }

        guard let previous = Material.with(material.ref, { material -> Material.Block? in
            material.blocks.indices.contains(index - 1) ? material.blocks[index - 1] : nil
        }) ?? nil else { return false }

        if case .text(_, let text)? = material.block(id: editing), text.isEmpty {
            blockFrames[editing] = nil
            material.delete([editing])
        }

        if case .text(_, let text) = previous {
            enterEditing(previous.id, caret: NSRange(location: (text as NSString).length, length: 0))
        } else {
            selectBlock(previous.id)
        }
        return true
    }

    private func deleteBlock() -> Bool {
        guard let id = selection.id else { return false }
        let landing = material.delete([id])

        guard let landing, let block = material.block(id: landing) else {
            return insertText(at: 0)
        }

        if case .text(_, let text) = block {
            enterEditing(landing, caret: NSRange(location: (text as NSString).length, length: 0))
        } else {
            selectBlock(landing)
        }
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
            guard let ref = ReferenceURL.reference(in: text.substring(with: link.url)),
                  ReferencePresentation.of(ref) == .component
            else { return nil }
            return link.range
        }
    }

    private func componentEnding(at range: NSRange) -> NSRange? {
        guard let text = editingText() else { return nil }
        return componentRanges(in: text).first { NSMaxRange($0) == range.location }
    }

    private func componentStarting(at range: NSRange) -> NSRange? {
        guard let text = editingText() else { return nil }
        return componentRanges(in: text).first { $0.location == range.location }
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
        ReferenceSelection.shared.selected = ReferenceURL.reference(in: text.substring(with: link.url))
    }

    private func step(_ offset: Int) -> Bool {
        guard let current = selection.id,
              let target = Material.with(material.ref, { material -> Material.Block? in
                  guard let index = material.blocks.firstIndex(where: { $0.id == current }) else { return nil }
                  let target = index + offset
                  return material.blocks.indices.contains(target) ? material.blocks[target] : nil
              }) ?? nil
        else { return false }

        if case .text(_, let text) = target {
            if let component = soleComponent(in: text) {
                selectComponent(component, in: target.id, text: text as NSString)
            } else {
                enterEditing(target.id, caret: NSRange(location: offset < 0 ? (text as NSString).length : 0, length: 0))
            }
        } else {
            selectBlock(target.id)
        }
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
        let blocks = Material.with(material.ref, { $0.blocks }) ?? []
        let lines = blocks.map { block -> String in
            if case .text(_, let text) = block { return text }
            return ""
        }

        for (block, line) in zip(blocks, Markdown.renumbered(lines)) {
            guard case .text(let id, let text) = block, text != line else { continue }
            material.write(line, to: id)
        }
    }

    private func ensureText(after index: Int) {
        if let next = Material.with(material.ref, { material -> Material.Block? in
            let next = index + 1
            guard material.blocks.indices.contains(next), case .text = material.blocks[next] else { return nil }
            return material.blocks[next]
        }) ?? nil {
            enterEditing(next.id, caret: NSRange(location: 0, length: 0))
        } else {
            _ = insertText(at: index + 1)
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
        if let caret {
            selection = .caret(id, caret)
        } else if case .text(_, let text)? = material.block(id: id) {
            selection = .caret(id, NSRange(location: (text as NSString).length, length: 0))
        } else {
            selection = .block(id)
        }
    }

    private func selectBlock(_ id: AnyHashable) {
        selection = .block(id)
    }

    func prepare() {
        material.inlineReferenceBlocks()
        activateTrailingText()
    }

    @discardableResult
    func activateTrailingText() -> AnyHashable? {
        guard let trailing = Material.with(material.ref, { $0.blocks.last }) ?? nil else {
            return insertText(at: 0) ? selection.id : nil
        }

        if case .text(_, let text) = trailing {
            enterEditing(trailing.id, caret: NSRange(location: (text as NSString).length, length: 0))
            return trailing.id
        }

        return insertText(at: Material.with(material.ref, { $0.blocks.endIndex }) ?? 0) ? selection.id : nil
    }

    func deactivate() {
        pruneTrailingEmptyText()
        selection = .none
    }

    @discardableResult
    private func endEditing() -> Bool {
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
