import SwiftUI
import UniformTypeIdentifiers
import ScintRuntime
import ScintComponents


internal typealias Block = ScintRuntime.Document.Block

extension ScintRuntime.Document.Block {
    /// One markdown chunk as a block: a heading or fenced code when it's exactly that, a paragraph otherwise.
    init(_ id: UUID, markdown: String) {
        let elements = Markdown.elements(markdown)
        let parsed: Self? = switch elements.count == 1 ? elements.first : nil {
            case .text(.heading(let level), let text, _, _)?: .heading(id, level, text)
            case .code(let text, let language)?: .code(id, language, text)
            default: nil
        }
        self = parsed.flatMap { $0.markdown == markdown ? $0 : nil } ?? .paragraph(id, markdown)
    }

    /// The markdown a prose block edits as.
    var markdown: String? {
        switch self {
            case .paragraph(_, let text): text
            case .heading(_, let level, let text): String(repeating: "#", count: level) + " " + text
            case .code(_, let language, let text): "```\(language)\n\(text)\n```"
            default: nil
        }
    }

    /// What it shows as a component: a block that holds a reference, or a paragraph that's nothing but a link to one.
    var reference: Reference? {
        switch self {
            case .artifact(let ref), .command(let ref), .document(let ref):
                return ref
            case .paragraph(_, let text):
                let source = text as NSString
                guard let link = Markdown.scan(text).links.first, link.range.length == source.length else { return nil }
                return Reference.Link.resolve(in: source.substring(with: link.url))
            default:
                return nil
        }
    }
}

struct EditorDocument: View {
    @Environment(\.undoManager) private var undoManager
    @State private var focus: Focus?
    @State private var selection: AnyHashable?
    @State private var rowFrames: [AnyHashable: CGRect] = [:]
    @State private var indicator: CGRect?
    @State private var resume: Focus?
    @State private var dragged: AnyHashable?
    @State private var typing: (id: AnyHashable, at: Date)?
    @State private var tail = UUID()

    let ref: Reference
    var autofocus = true
    var onOpenLink: (EditorLink) -> Void = { _ in }

    static let line: CGFloat = {
        let font = Typography.Prose.text
        return ceil(font.ascender - font.descender + font.leading)
    }()

    private var blocks: [Block] { ScintRuntime.Document.with(ref, { $0.blocks }) ?? [] }

    /// Everything but the metadata and a task's header. A document's heading is its title, and edits like any other line.
    private var rows: [Block] {
        let blocks = ScintRuntime.Document.with(ref, { $0.task == nil ? $0.blocks.filter { if case .metadata = $0 { false } else { true } } : $0.body }) ?? []
        if case .paragraph? = blocks.last { return blocks }
        return blocks + [.paragraph(tail, "")]
    }

    struct Focus: Equatable {
        let id: AnyHashable
        var entry: Exit?
        var caret: Int?
        let request = UUID()
    }

    var body: some View {
        let rows = rows
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, block in row(block, at: index, in: rows) }
        }
        .coordinateSpace(.named("blocks"))
        .overlay {
            if dragged != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { dragged = nil; indicator = nil }
                    .onDrop(of: [.block], delegate: BlockDrop(
                        onUpdate: { indicator = aim(at: $0)?.line },
                        onExit: { indicator = nil },
                        onPerform: { point in
                            indicator = nil
                            guard let aim = aim(at: point) else { dragged = nil; return false }
                            return drop(onto: aim.target)
                        }
                    ))
                    .overlay(alignment: .topLeading) {
                        if let indicator {
                            Capsule()
                                .fill(Style.Tint.accent.bright)
                                .frame(width: indicator.width, height: indicator.height)
                                .offset(x: indicator.minX, y: indicator.minY)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
        .padding(.leading, -20)
        .background {
            BlockKeys(active: selection != nil) { selector in
                switch selector {
                    case #selector(NSResponder.deleteBackward(_:)), #selector(NSResponder.deleteForward(_:)): deleteSelection()
                    case #selector(NSResponder.moveUp(_:)): moveSelection(.previous)
                    case #selector(NSResponder.moveDown(_:)): moveSelection(.next)
                    case #selector(NSResponder.insertNewline(_:)): editSelection(opening: true)
                    case #selector(NSResponder.cancelOperation(_:)): editSelection(opening: false)
                    default: false
                }
            }
        }
        .onAppear {
            let split = { (block: Block) -> [Block]? in
                guard case .paragraph(let uuid, let text) = block, let first = Markdown.chunks(text).first else { return nil }
                let chunked = [Block(uuid, markdown: first)] + Markdown.chunks(text).dropFirst().map { Block(UUID(), markdown: $0) }
                return chunked == [block] ? nil : chunked
            }
            if blocks.contains(where: { split($0) != nil }) {
                ScintRuntime.Document.update(ref) { document in
                    for (index, block) in document.blocks.enumerated().reversed() {
                        guard let chunked = split(block) else { continue }
                        document.update(chunked[0], at: index)
                        document.insert(Array(chunked.dropFirst()), at: index + 1)
                    }
                }
            }
            if autofocus, focus == nil, let last = self.rows.last { focus = Focus(id: last.id, entry: .previous) }
        }
    }

    private func row(_ block: Block, at index: Int, in rows: [Block]) -> some View {
        let above: Block? = index > 0 ? rows[index - 1] : nil
        let first = block.markdown.flatMap { Markdown.scan($0).blocks.first }
        let gap: CGFloat = switch (above, block) {
            case (nil, _): 0
            case (.task?, .task): Typography.Prose.listItemSpacing
            default:
                if let last = above?.markdown.flatMap({ Markdown.scan($0).blocks.last }), let first { Styler.spacing(after: last.kind, before: first.kind) }
                else { Typography.Prose.blockSpacing }
        }
        var start = 0
        if let first, first.kind == .numbered {
            scan: for row in rows[..<index].reversed() {
                guard case .paragraph(_, let text) = row, !text.isEmpty else { break }
                for line in Markdown.scan(text).blocks.reversed() {
                    guard line.kind.isList, line.depth >= first.depth else { break scan }
                    guard line.depth == first.depth else { continue }
                    guard line.kind == .numbered else { break scan }
                    start += 1
                }
            }
        }
        return BlockRow(
            gap: gap,
            selected: selection == block.id && Self.edits(block),
            handled: selection == block.id || focus?.id == block.id,
            onSelect: { select(block.id) },
            onDrag: { drag(block.id) },
            onFrame: { rowFrames[block.id] = $0 },
            onTap: { above in
                select(nil)
                enter(above && index > 0 ? rows[index - 1] : block, from: .previous)
            }
        ) {
            content(block, at: index, in: rows, listStart: start)
        }
    }

    @ViewBuilder private func content(_ block: Block, at index: Int, in rows: [Block], listStart start: Int) -> some View {
        switch block {
            case .paragraph(_, let text) where Markdown.Table(text) != nil:
                TableEditor(.init(get: { self.text(of: block.id) }, set: { type(block.id, $0) }))

            case .paragraph where block.reference != nil:
                component(block)

            // One branch for all prose, so a paragraph that becomes a heading keeps its editor.
            case .paragraph, .heading, .code:
                let text = block.markdown ?? ""
                if focus?.id != block.id {
                    BlockTextView(text: text, listStart: start, onClick: { select(nil); focus = Focus(id: block.id, caret: $0) })
                } else {
                    editor(block.id, text, listStart: start, onSplit: { before, after in
                        change("Split") {
                            write(block.id, before)
                            insert([Block(UUID(), markdown: after)], at: block.id, focusing: true)
                        }
                        return true
                    }, onDeleteAtStart: {
                        guard index > 0 else { return false }
                        let above = rows[index - 1]
                        switch above {
                            case .task(let uuid, let previous, let completed):
                                change("Join") {
                                    update(above.id) { _ in .task(uuid, previous + text, completed) }
                                    delete(block.id)
                                }
                                focus = Focus(id: above.id, caret: (previous as NSString).length)
                            default:
                                if let previous = above.markdown, Self.edits(above) {
                                    change("Join") {
                                        write(above.id, previous + text)
                                        delete(block.id)
                                    }
                                    focus = Focus(id: above.id, caret: (previous as NSString).length)
                                }
                                else if text.isEmpty { change("Delete") { remove(block.id, then: .previous) } }
                                else { enter(above, from: .previous) }
                        }
                        return true
                    })
                }

            case .task(let uuid, let text, let completed):
                TaskRow(
                    completed: completed,
                    onToggle: { change("Check") { update(block.id) { _ in .task(uuid, text, !completed) } } }
                ) {
                    if focus?.id != block.id { BlockTextView(text: text, onClick: { select(nil); focus = Focus(id: block.id, caret: $0) }) }
                    else { editor(block.id, text, placeholder: "Task", commands: false, onSplit: { before, after in
                        guard case .task(_, _, let completed)? = self.block(block.id) else { return false }
                        change("Split") {
                            if before.isEmpty, after.isEmpty { return remove(block.id, then: .next) }
                            update(block.id) { _ in .task(uuid, before, completed) }
                            insert([.task(UUID(), after, false)], at: block.id, focusing: true)
                        }
                        return true
                    }, onDeleteAtStart: {
                        guard case .task(_, let text, _)? = self.block(block.id), text.isEmpty else { return false }
                        change("Delete") { remove(block.id, then: .previous) }
                        return true
                    }) }
                }

            default:
                component(block)
        }
    }

    private func component(_ block: Block) -> some View {
        let ref = block.reference
        return BlockCard(
            onSelect: { select(block.id) },
            onOpen: { if let ref { onOpenLink(.reference(ref)) } },
            onDrag: { drag(block.id) },
            onFrame: { _ in }
        ) {
            if case .paragraph = block, let ref { Card(ref: ref, style: .group, isSelected: selection == block.id) }
            else { DocumentBlock(block: block, isSelected: selection == block.id) }
        }
    }

    private func editor(_ id: AnyHashable, _ text: String, listStart: Int = 0, placeholder: String = "Press ‘/’ for commands", commands: Bool = true,
                        onSplit: @escaping (String, String) -> Bool, onDeleteAtStart: @escaping () -> Bool) -> EditorView {
        EditorView(
            text: text,
            focus: focus?.id == id ? focus : nil,
            onFocus: { selection = nil; if focus?.id != id { focus = Focus(id: id) } },
            onChange: { type(id, $0) },
            onInsert: { blocks, offset in change("Insert") { insert(blocks, at: id, splitting: offset) } },
            onExit: { move(from: id, $0) },
            onSplit: onSplit,
            onDeleteAtStart: onDeleteAtStart,
            onEscape: { select(id, caret: $0); return true },
            listStart: listStart,
            onOpenLink: onOpenLink,
            placeholder: placeholder,
            commands: commands
        )
    }

    private func block(_ id: AnyHashable) -> Block? { rows.first { $0.id == id } }

    private func text(of id: AnyHashable) -> String {
        switch block(id) {
            case .task(_, let text, _)?: text
            case let block?: block.markdown ?? ""
            case nil: ""
        }
    }

    private static func edits(_ block: Block) -> Bool {
        switch block {
            case .task, .heading, .code: true
            case .paragraph(_, let text): Markdown.Table(text) == nil && block.reference == nil
            default: false
        }
    }

    private func type(_ id: AnyHashable, _ text: String) {
        if typing?.id != id || Date.now.timeIntervalSince(typing?.at ?? .distantPast) > 2 { checkpoint("Typing") }
        typing = (id, .now)
        write(id, text)
    }

    private func enter(_ block: Block, from exit: Exit) {
        if Self.edits(block) { focus = Focus(id: block.id, entry: exit) }
        else { select(block.id) }
    }

    private func move(from id: AnyHashable, _ exit: Exit) -> Bool {
        let rows = rows
        guard let index = rows.firstIndex(where: { $0.id == id }), rows.indices.contains(index + (exit == .next ? 1 : -1)) else { return false }
        enter(rows[index + (exit == .next ? 1 : -1)], from: exit)
        return true
    }

    private func select(_ id: AnyHashable?, caret: Int? = nil) {
        selection = id
        guard let id else { return }
        resume = Focus(id: id, entry: caret == nil ? .previous : nil, caret: caret)
        focus = nil
    }

    private func moveSelection(_ exit: Exit) -> Bool {
        let rows = rows
        guard let selection, let index = rows.firstIndex(where: { $0.id == selection }) else { return false }
        let target = index + (exit == .next ? 1 : -1)
        guard rows.indices.contains(target) else { return true }
        if Self.edits(rows[index]) { select(rows[target].id) }
        else { enter(rows[target], from: exit) }
        return true
    }

    private func editSelection(opening: Bool) -> Bool {
        guard let selection, let block = block(selection) else { return false }
        if Self.edits(block) { select(nil); focus = resume }
        else if opening {
            select(nil)
            change("Insert") { insert([.paragraph(UUID(), "")], at: selection, focusing: true) }
        }
        else { select(nil) }
        return true
    }

    private func deleteSelection() -> Bool {
        let rows = rows
        guard let selection, let index = rows.firstIndex(where: { $0.id == selection }) else { return false }
        let row = rows.indices.contains(index + 1) ? index + 1 : index - 1
        let next = rows.indices.contains(row) && rows[row].id != AnyHashable(tail) ? rows[row].id : nil
        change("Delete") { delete(selection) }
        select(next)
        return true
    }

    private func drag(_ id: AnyHashable) -> NSItemProvider {
        dragged = id
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.block.identifier, visibility: .ownProcess) { $0(Data(), nil); return nil }
        return provider
    }

    private func aim(at point: CGPoint) -> (target: AnyHashable?, line: CGRect)? {
        let placed = rows.compactMap { row in rowFrames[row.id].map { (id: row.id, frame: $0) } }.sorted { $0.frame.minY < $1.frame.minY }
        guard let last = placed.last else { return nil }
        guard let index = placed.firstIndex(where: { point.y < $0.frame.midY }) else {
            return (nil, CGRect(x: last.frame.minX, y: last.frame.maxY + 4, width: last.frame.width, height: 3))
        }
        let above = index > 0 ? placed[index - 1].frame.maxY : placed[index].frame.minY - 8
        let frame = placed[index].frame
        return (placed[index].id, CGRect(x: frame.minX, y: (above + frame.minY) / 2 - 1.5, width: frame.width, height: 3))
    }

    private func drop(onto target: AnyHashable?) -> Bool {
        guard let dragged, dragged != target, let moving = block(dragged) else { self.dragged = nil; return false }
        let kept = blocks.filter { $0.id != dragged }
        let moved = kept.flatMap { $0.id == target ? [moving, $0] : [$0] }
        change("Move") { Self.replace(kept.contains { $0.id == target } ? moved : moved + [moving], in: ref) }
        self.dragged = nil
        return true
    }

    private static func replace(_ blocks: [Block], in document: Reference) {
        ScintRuntime.Document.update(document) { document in
            for _ in document.blocks.indices { document.delete(at: 0) }
            document.insert(blocks, at: 0)
        }
    }

    private func change(_ name: String, _ body: () -> Void) {
        checkpoint(name)
        typing = nil
        body()
    }

    private func checkpoint(_ name: String) {
        guard let undoManager else { return }
        let document = ref, blocks = blocks
        undoManager.registerUndo(withTarget: undoManager) { Self.restore(blocks, in: document, $0) }
        undoManager.setActionName(name)
    }

    private static func restore(_ blocks: [Block], in document: Reference, _ undoManager: UndoManager) {
        let current = ScintRuntime.Document.with(document, { $0.blocks }) ?? []
        undoManager.registerUndo(withTarget: undoManager) { restore(current, in: document, $0) }
        replace(blocks, in: document)
    }

    private func update(_ id: AnyHashable, _ change: (Block) -> Block) {
        ScintRuntime.Document.update(ref) { document in
            guard let index = document.blocks.firstIndex(where: { $0.id == id }) else { return }
            document.update(change(document.blocks[index]), at: index)
        }
    }

    /// Typed text, kept as the block it now reads as: `# ` makes a paragraph a heading, and deleting it makes it a paragraph again.
    private func write(_ id: AnyHashable, _ text: String) {
        guard id == AnyHashable(tail) else {
            return update(id) { block in
                switch block {
                    case .paragraph(let uuid, _), .heading(let uuid, _, _), .code(let uuid, _, _): Block(uuid, markdown: text)
                    case .task(let uuid, _, let completed): .task(uuid, text, completed)
                    default: block
                }
            }
        }
        ScintRuntime.Document.update(ref) { $0.insert(Block(tail, markdown: text), at: nil) }
        tail = UUID()
    }

    private func delete(_ id: AnyHashable) {
        ScintRuntime.Document.update(ref) { document in
            if let index = document.blocks.firstIndex(where: { $0.id == id }) { document.delete(at: index) }
        }
    }

    private func remove(_ id: AnyHashable, then exit: Exit) {
        _ = move(from: id, exit)
        delete(id)
    }

    private func insert(_ blocks: [Block], at id: AnyHashable, splitting offset: Int? = nil, focusing: Bool = false) {
        var continued = false
        ScintRuntime.Document.update(ref) { document in
            guard let index = document.blocks.firstIndex(where: { $0.id == id }) else { return document.insert(blocks, at: nil) }
            guard let offset, let text = document.blocks[index].markdown, let uuid = document.blocks[index].id as? UUID
            else { return document.insert(blocks, at: index + 1) }
            let source = text as NSString, split = min(offset, source.length)
            let before = source.substring(to: split).trimmingCharacters(in: .newlines)
            let after = source.substring(from: split).trimmingCharacters(in: .newlines)
            continued = !after.isEmpty
            document.delete(at: index)
            document.insert((before.isEmpty ? [] : [Block(uuid, markdown: before)]) + blocks + (after.isEmpty ? [] : [Block(UUID(), markdown: after)]), at: index)
        }
        if focusing, let first = blocks.first { focus = Focus(id: first.id, entry: .next); return }
        let rows = rows
        guard let last = blocks.last?.id, let index = rows.firstIndex(where: { $0.id == last }) else { return }
        if rows.indices.contains(index + 1), let text = rows[index + 1].markdown, text.isEmpty || continued {
            return enter(rows[index + 1], from: .next)
        }
        let line = UUID()
        ScintRuntime.Document.update(ref) { document in
            document.insert(.paragraph(line, ""), at: document.blocks.firstIndex { $0.id == last }.map { $0 + 1 })
        }
        focus = Focus(id: line, entry: .next)
    }
}
