import SwiftUI
import UniformTypeIdentifiers
import ScintRuntime
import ScintComponents


internal typealias Block = ScintRuntime.Document.Block

struct EditorDocument: View {
    @Environment(\.undoManager) private var undoManager
    @State private var focus: Focus?
    @State private var selection: Int?
    @State private var rowFrames: [Int: CGRect] = [:]
    @State private var indicator: CGRect?
    @State private var resume: Focus?
    @State private var dragged: Int?
    @State private var typing: (row: Int, at: Date)?

    let ref: Reference
    var autofocus = true
    var onOpenLink: (EditorLink) -> Void = { _ in }

    static let line: CGFloat = {
        let font = Typography.Prose.text
        return ceil(font.ascender - font.descender + font.leading)
    }()

    static func block(_ id: UUID, markdown: String) -> Block {
        let elements = Markdown.elements(markdown)
        let parsed: Block? = switch elements.count == 1 ? elements.first : nil {
            case .text(.heading(let level), let text, _, _)?: .heading(id, level, text)
            case .code(let text, let language)?: .code(id, language, text)
            default: nil
        }
        return parsed.flatMap { Self.markdown($0) == markdown ? $0 : nil } ?? .paragraph(id, markdown)
    }

    static func markdown(_ block: Block) -> String? {
        switch block {
            case .paragraph(_, let text): text
            case .heading(_, let level, let text): String(repeating: "#", count: level) + " " + text
            case .code(_, let language, let text): "```\(language)\n\(text)\n```"
            default: nil
        }
    }

    static func reference(_ block: Block) -> Reference? {
        switch block {
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

    private var blocks: [Block] { ScintRuntime.Document.with(ref, { $0.blocks }) ?? [] }

    private var header: Int {
        ScintRuntime.Document.with(ref, { $0.header != .task ? ($0.metadata == nil ? 0 : 1) : $0.blocks.count - $0.body.count }) ?? 0
    }

    private var rows: [Block] {
        let rows = Array(blocks.dropFirst(header))
        if case .paragraph? = rows.last { return rows }
        return rows + [.paragraph(UUID(), "")]
    }

    private func position(_ row: Int) -> Int { header + row }

    struct Focus: Equatable {
        let row: Int
        var entry: Exit?
        var caret: Int?
        let request = UUID()
    }

    var body: some View {
        let rows = rows
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, block in row(block, at: index, in: rows) }
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
                let chunked = [Self.block(uuid, markdown: first)] + Markdown.chunks(text).dropFirst().map { Self.block(UUID(), markdown: $0) }
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
            if autofocus, focus == nil, !self.rows.isEmpty { focus = Focus(row: self.rows.count - 1, entry: .previous) }
        }
    }

    private func row(_ block: Block, at index: Int, in rows: [Block]) -> some View {
        let above: Block? = index > 0 ? rows[index - 1] : nil
        let first = Self.markdown(block).flatMap { Markdown.scan($0).blocks.first }
        let gap: CGFloat = switch (above, block) {
            case (nil, _): 0
            case (.task?, .task): Typography.Prose.listItemSpacing
            default:
                if let last = above.flatMap(Self.markdown).flatMap({ Markdown.scan($0).blocks.last }), let first { Styler.spacing(after: last.kind, before: first.kind) }
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
            selected: selection == index && Self.edits(block),
            handled: selection == index || focus?.row == index,
            onSelect: { select(index) },
            onDrag: { drag(index) },
            onFrame: { rowFrames[index] = $0 },
            onTap: { above in
                select(nil)
                enter(above && index > 0 ? index - 1 : index, from: .previous)
            }
        ) {
            content(block, at: index, in: rows, listStart: start)
        }
    }

    @ViewBuilder private func content(_ block: Block, at index: Int, in rows: [Block], listStart start: Int) -> some View {
        switch block {
            case .paragraph(_, let text) where Markdown.Table(text) != nil:
                TableEditor(.init(get: { self.text(of: index) }, set: { type(index, $0) }))

            case .paragraph where Self.reference(block) != nil:
                component(block, at: index)

            case .paragraph, .heading, .code:
                let text = Self.markdown(block) ?? ""
                if focus?.row != index {
                    BlockTextView(text: text, listStart: start, onClick: { select(nil); focus = Focus(row: index, caret: $0) })
                } else {
                    editor(index, text, listStart: start, onSplit: { before, after in
                        change("Split") {
                            write(index, before)
                            insert([Self.block(UUID(), markdown: after)], at: index, focusing: true)
                        }
                        return true
                    }, onDeleteAtStart: {
                        guard index > 0 else { return false }
                        let above = rows[index - 1]
                        switch above {
                            case .task(let uuid, let previous, let completed):
                                change("Join") {
                                    update(index - 1) { _ in .task(uuid, previous + text, completed) }
                                    delete(index)
                                }
                                focus = Focus(row: index - 1, caret: (previous as NSString).length)
                            default:
                                if let previous = Self.markdown(above), Self.edits(above) {
                                    change("Join") {
                                        write(index - 1, previous + text)
                                        delete(index)
                                    }
                                    focus = Focus(row: index - 1, caret: (previous as NSString).length)
                                }
                                else if text.isEmpty { change("Delete") { remove(index, then: .previous) } }
                                else { enter(index - 1, from: .previous) }
                        }
                        return true
                    })
                }

            case .task(let uuid, let text, let completed):
                TaskRow(
                    completed: completed,
                    onToggle: { change("Check") { update(index) { _ in .task(uuid, text, !completed) } } }
                ) {
                    if focus?.row != index { BlockTextView(text: text, onClick: { select(nil); focus = Focus(row: index, caret: $0) }) }
                    else { editor(index, text, placeholder: "Task", commands: false, onSplit: { before, after in
                        guard case .task(_, _, let completed)? = self.block(index) else { return false }
                        change("Split") {
                            if before.isEmpty, after.isEmpty { return remove(index, then: .next) }
                            update(index) { _ in .task(uuid, before, completed) }
                            insert([.task(UUID(), after, false)], at: index, focusing: true)
                        }
                        return true
                    }, onDeleteAtStart: {
                        guard case .task(_, let text, _)? = self.block(index), text.isEmpty else { return false }
                        change("Delete") { remove(index, then: .previous) }
                        return true
                    }) }
                }

            default:
                component(block, at: index)
        }
    }

    private func component(_ block: Block, at index: Int) -> some View {
        let ref = Self.reference(block)
        return BlockCard(
            onSelect: { select(index) },
            onOpen: { if let ref { onOpenLink(.reference(ref)) } },
            onDrag: { drag(index) },
            onFrame: { _ in }
        ) {
            if case .paragraph = block, let ref { Card(ref: ref, style: .group, isSelected: selection == index) }
            else { DocumentBlock(block: block, isSelected: selection == index) }
        }
    }

    private func editor(_ row: Int, _ text: String, listStart: Int = 0, placeholder: String = "Press ‘/’ for commands", commands: Bool = true,
                        onSplit: @escaping (String, String) -> Bool, onDeleteAtStart: @escaping () -> Bool) -> EditorView {
        EditorView(
            text: text,
            focus: focus?.row == row ? focus : nil,
            onFocus: { selection = nil; if focus?.row != row { focus = Focus(row: row) } },
            onChange: { type(row, $0) },
            onInsert: { blocks, offset in change("Insert") { insert(blocks, at: row, splitting: offset) } },
            onExit: { move(from: row, $0) },
            onSplit: onSplit,
            onDeleteAtStart: onDeleteAtStart,
            onEscape: { select(row, caret: $0); return true },
            listStart: listStart,
            onOpenLink: onOpenLink,
            placeholder: placeholder,
            commands: commands
        )
    }

    private func block(_ row: Int) -> Block? {
        let rows = rows
        return rows.indices.contains(row) ? rows[row] : nil
    }

    private func text(of row: Int) -> String {
        switch block(row) {
            case .task(_, let text, _)?: text
            case let block?: Self.markdown(block) ?? ""
            case nil: ""
        }
    }

    private static func edits(_ block: Block) -> Bool {
        switch block {
            case .task, .heading, .code: true
            case .paragraph(_, let text): Markdown.Table(text) == nil && reference(block) == nil
            default: false
        }
    }

    private func type(_ row: Int, _ text: String) {
        if typing?.row != row || Date.now.timeIntervalSince(typing?.at ?? .distantPast) > 2 { checkpoint("Typing") }
        typing = (row, .now)
        write(row, text)
        if block(row).flatMap(Self.reference) != nil { proceed(after: row) }
    }

    private func enter(_ row: Int, from exit: Exit) {
        guard let block = block(row) else { return }
        if Self.edits(block) { focus = Focus(row: row, entry: exit) }
        else { select(row) }
    }

    private func move(from row: Int, _ exit: Exit) -> Bool {
        let target = row + (exit == .next ? 1 : -1)
        guard rows.indices.contains(target) else { return false }
        enter(target, from: exit)
        return true
    }

    private func select(_ row: Int?, caret: Int? = nil) {
        selection = row
        guard let row else { return }
        resume = Focus(row: row, entry: caret == nil ? .previous : nil, caret: caret)
        focus = nil
    }

    private func moveSelection(_ exit: Exit) -> Bool {
        let rows = rows
        guard let selection, rows.indices.contains(selection) else { return false }
        let target = selection + (exit == .next ? 1 : -1)
        guard rows.indices.contains(target) else { return true }
        if Self.edits(rows[selection]) { select(target) }
        else { enter(target, from: exit) }
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
        guard let selection, rows.indices.contains(selection) else { return false }
        change("Delete") { delete(selection) }
        select(nil)
        if rows.indices.contains(selection) { enter(selection, from: .next) }
        else if selection > 0 { enter(selection - 1, from: .previous) }
        return true
    }

    private func drag(_ row: Int) -> NSItemProvider {
        dragged = row
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.block.identifier, visibility: .ownProcess) { $0(Data(), nil); return nil }
        return provider
    }

    private func aim(at point: CGPoint) -> (target: Int?, line: CGRect)? {
        let placed = rows.indices.compactMap { row in rowFrames[row].map { (row: row, frame: $0) } }.sorted { $0.frame.minY < $1.frame.minY }
        guard let last = placed.last else { return nil }
        guard let index = placed.firstIndex(where: { point.y < $0.frame.midY }) else {
            return (nil, CGRect(x: last.frame.minX, y: last.frame.maxY + 4, width: last.frame.width, height: 3))
        }
        let above = index > 0 ? placed[index - 1].frame.maxY : placed[index].frame.minY - 8
        let frame = placed[index].frame
        return (placed[index].row, CGRect(x: frame.minX, y: (above + frame.minY) / 2 - 1.5, width: frame.width, height: 3))
    }

    private func drop(onto target: Int?) -> Bool {
        defer { self.dragged = nil }
        guard let dragged, dragged != target, position(dragged) < blocks.count else { return false }
        let from = position(dragged), to = target.map(position) ?? blocks.count
        change("Move") {
            ScintRuntime.Document.update(ref) { document in
                let moving = document.blocks[from]
                document.delete(at: from)
                document.insert(moving, at: min(to > from ? to - 1 : to, document.blocks.count))
            }
        }
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

    private func update(_ row: Int, _ change: (Block) -> Block) {
        let index = position(row)
        ScintRuntime.Document.update(ref) { document in
            guard document.blocks.indices.contains(index) else { return }
            document.update(change(document.blocks[index]), at: index)
        }
    }

    private func write(_ row: Int, _ text: String) {
        guard position(row) >= blocks.count else {
            return update(row) { block in
                switch block {
                    case .paragraph(let uuid, _), .heading(let uuid, _, _), .code(let uuid, _, _): Self.block(uuid, markdown: text)
                    case .task(let uuid, _, let completed): .task(uuid, text, completed)
                    default: block
                }
            }
        }
        ScintRuntime.Document.update(ref) { $0.insert(Self.block(UUID(), markdown: text), at: nil) }
    }

    private func delete(_ row: Int) {
        let index = position(row)
        ScintRuntime.Document.update(ref) { $0.delete(at: index) }
    }

    private func remove(_ row: Int, then exit: Exit) {
        delete(row)
        let target = exit == .next ? row : row - 1
        if rows.indices.contains(target) { enter(target, from: exit) }
    }

    private func insert(_ blocks: [Block], at row: Int, splitting offset: Int? = nil, focusing: Bool = false) {
        let index = position(row)
        var continued = false, first = row + 1
        ScintRuntime.Document.update(ref) { document in
            guard document.blocks.indices.contains(index) else { first = row; return document.insert(blocks, at: nil) }
            guard let offset, let text = Self.markdown(document.blocks[index]), let uuid = document.blocks[index].id as? UUID
            else { return document.insert(blocks, at: index + 1) }
            let source = text as NSString, split = min(offset, source.length)
            let before = source.substring(to: split).trimmingCharacters(in: .newlines)
            let after = source.substring(from: split).trimmingCharacters(in: .newlines)
            continued = !after.isEmpty
            if before.isEmpty { first = row }
            document.delete(at: index)
            document.insert((before.isEmpty ? [] : [Self.block(uuid, markdown: before)]) + blocks + (after.isEmpty ? [] : [Self.block(UUID(), markdown: after)]), at: index)
        }
        guard !blocks.isEmpty else { return }
        if focusing { focus = Focus(row: first, entry: .next); return }
        proceed(after: first + blocks.count - 1, continued: continued)
    }

    private func proceed(after row: Int, continued: Bool = false) {
        let rows = rows, next = row + 1
        if rows.indices.contains(next), let text = Self.markdown(rows[next]), text.isEmpty || continued {
            return enter(next, from: .next)
        }
        let line = position(next)
        ScintRuntime.Document.update(ref) { $0.insert(.paragraph(UUID(), ""), at: line) }
        focus = Focus(row: next, entry: .next)
    }
}
