import SwiftUI
import UniformTypeIdentifiers
import ScintRuntime
import ScintComponents


struct BlockKeys: NSViewRepresentable {
    let active: Bool
    var onCommand: (Selector) -> Bool

    final class Responder: NSView {
        var onCommand: (Selector) -> Bool = { _ in false }

        override var acceptsFirstResponder: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func keyDown(with event: NSEvent) { interpretKeyEvents([event]) }
        override func doCommand(by selector: Selector) { if !onCommand(selector) { super.doCommand(by: selector) } }
    }

    func makeNSView(context: Self.Context) -> Responder { Responder() }

    func updateNSView(_ view: Responder, context: Self.Context) {
        view.onCommand = onCommand
        guard active, view.window?.firstResponder !== view else { return }
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
    }
}

struct BlockDrop: DropDelegate {
    var onUpdate: (CGPoint) -> Void
    var onExit: () -> Void
    var onPerform: (CGPoint) -> Bool

    func dropUpdated(info: DropInfo) -> DropProposal? { onUpdate(info.location); return DropProposal(operation: .move) }
    func dropExited(info: DropInfo) { onExit() }
    func performDrop(info: DropInfo) -> Bool { onPerform(info.location) }
}

struct BlockRow<Content: View>: View {
    let gap: CGFloat
    let selected: Bool
    let handled: Bool
    var onSelect: () -> Void
    var onDrag: () -> NSItemProvider
    var onFrame: (CGRect) -> Void
    var onTap: (Bool) -> Void
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11))
                .foregroundStyle(Style.Foreground.secondary)
                .frame(width: 16, height: BlockList.line)
                .contentShape(Rectangle())
                .opacity(handled ? 1 : 0)
                .onTapGesture(perform: onSelect)
                .onDrag(onDrag)
                .opacity(0.0)
            content
                .background { if selected { Style.Shape.card.fill(Style.Background.selection).padding(-4) } }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("blocks")) } action: { onFrame($0) }
        .padding(.top, gap)
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in onTap(location.y < gap / 2) }
    }
}

struct BlockCard<Content: View>: View {
    var onSelect: () -> Void
    var onOpen: () -> Void
    var onDrag: () -> NSItemProvider
    var onFrame: (CGRect) -> Void
    @ViewBuilder let content: Content

    var body: some View {
        content
            .contentShape(Rectangle())
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("blocks")) } action: { onFrame($0) }
            .simultaneousGesture(TapGesture().onEnded(onSelect))
            .simultaneousGesture(TapGesture().modifiers(.command).onEnded(onOpen))
            .onDrag(onDrag)
    }
}

struct TaskRow<Editor: View>: View {
    let completed: Bool
    var onToggle: () -> Void
    @ViewBuilder let editor: Editor

    var body: some View {
        HStack(alignment: .top, spacing: Typography.Prose.markerGap) {
            Button(action: onToggle) { TaskCompletionIndicator(completed: completed) }
                .buttonStyle(.plain)
                .frame(width: Typography.Prose.markerWidth, height: BlockList.line)
            editor.opacity(completed ? Style.Opacity.inactive : 1)
        }
        .padding(.leading, Typography.Prose.listInset)
    }
}

struct BlockList: View {
    typealias Block = ScintRuntime.Document.Block

    struct Focus: Equatable {
        let id: AnyHashable
        var entry: ScintEditor.Exit?
        var caret: Int?
        let request = UUID()
    }

    let document: Reference
    var autofocus = true
    var onOpenLink: (EditorLink) -> Void = { _ in }

    @Environment(\.undoManager) private var undoManager
    @State private var focus: Focus?
    @State private var selection: AnyHashable?
    @State private var rowFrames: [AnyHashable: CGRect] = [:]
    @State private var cardFrames: [AnyHashable: CGRect] = [:]
    @State private var indicator: CGRect?
    @State private var resume: Focus?
    @State private var dragged: AnyHashable?
    @State private var typing: (id: AnyHashable, at: Date)?
    @State private var tail = UUID()

    static let line: CGFloat = {
        let font = Typography.Prose.text
        return ceil(font.ascender - font.descender + font.leading)
    }()

    private var blocks: [Block] { ScintRuntime.Document.with(document, { $0.blocks }) ?? [] }

    private var rows: [Block] {
        let blocks = blocks
        if case .text? = blocks.last { return blocks }
        return blocks + [.text(tail, "")]
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
                            return drop(onto: aim.target, beside: aim.beside)
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
                    case #selector(NSResponder.moveLeft(_:)): moveSideways(-1)
                    case #selector(NSResponder.moveRight(_:)): moveSideways(1)
                    case #selector(NSResponder.insertNewline(_:)): editSelection(opening: true)
                    case #selector(NSResponder.cancelOperation(_:)): editSelection(opening: false)
                    default: false
                }
            }
        }
        .onAppear {
            let split = blocks.contains { block in
                guard case .text(_, let text) = block else { return false }
                let chunks = Markdown.chunks(text)
                return !chunks.isEmpty && chunks != [text]
            }
            if split {
                ScintRuntime.Document.update(document) { document in
                    for (index, block) in document.blocks.enumerated().reversed() {
                        guard case .text(let uuid, let text) = block else { continue }
                        let chunks = Markdown.chunks(text)
                        guard let first = chunks.first, chunks != [text] else { continue }
                        document.update(.text(uuid, first), at: index)
                        document.insert(chunks.dropFirst().map { .text(UUID(), $0) }, at: index + 1)
                    }
                }
            }
            if autofocus, focus == nil, let last = self.rows.last { focus = Focus(id: last.id, entry: .previous) }
        }
    }

    private func row(_ block: Block, at index: Int, in rows: [Block]) -> some View {
        let above: Block? = index > 0 ? rows[index - 1] : nil
        let first = if case .text(_, let text) = block { Markdown.scan(text).blocks.first } else { Markdown.Block?.none }
        let gap: CGFloat = switch (above, block) {
            case (nil, _): 0
            case (.task?, .task): Typography.Prose.listSpacing
            case (.text(_, let text)?, .text):
                if let last = Markdown.scan(text).blocks.last, let first { Styler.spacing(after: last, before: first) }
                else { Typography.Prose.blockSpacing }
            default: Typography.Prose.blockSpacing
        }
        var start = 0
        if let first, first.kind == .numbered {
            scan: for row in rows[..<index].reversed() {
                guard case .text(_, let text) = row, !text.isEmpty else { break }
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
            case .text(_, let text) where Markdown.Table(text) != nil:
                TableEditor(.init(get: { self.text(of: block.id) }, set: { type(block.id, $0) }))

            case .text(_, let text) where Self.reference(in: text) != nil:
                component(block)


            case .text(_, let text) where focus?.id != block.id:
                BlockTextView(text: text, listStart: start, onClick: { select(nil); focus = Focus(id: block.id, caret: $0) })

            case .text(_, let text):
                editor(block.id, text, listStart: start, onSplit: { before, after in
                    change("Split") {
                        write(block.id, before)
                        insert([.text(UUID(), after)], at: block.id, focusing: true)
                    }
                    return true
                }, onDeleteAtStart: {
                    guard index > 0 else { return false }
                    let above = rows[index - 1]
                    switch above {
                        case .text(let uuid, let previous) where Self.edits(above):
                            change("Join") {
                                update(above.id) { _ in .text(uuid, previous + text) }
                                delete(block.id)
                            }
                            focus = Focus(id: above.id, caret: (previous as NSString).length)
                        case .task(let uuid, let previous, let completed, let when):
                            change("Join") {
                                update(above.id) { _ in .task(uuid, previous + text, completed, when) }
                                delete(block.id)
                            }
                            focus = Focus(id: above.id, caret: (previous as NSString).length)
                        default:
                            if text.isEmpty { change("Delete") { remove(block.id, then: .previous) } }
                            else { enter(above, from: .previous) }
                    }
                    return true
                })

            case .task(let uuid, let text, let completed, let when):
                TaskRow(
                    completed: completed,
                    onToggle: { change("Check") { update(block.id) { _ in .task(uuid, text, !completed, when) } } }
                ) {
                    if focus?.id != block.id { BlockTextView(text: text, onClick: { select(nil); focus = Focus(id: block.id, caret: $0) }) }
                    else { editor(block.id, text, placeholder: "Task", commands: false, onSplit: { before, after in
                        guard case .task(_, _, let completed, let when)? = self.block(block.id) else { return false }
                        change("Split") {
                            if before.isEmpty, after.isEmpty { return remove(block.id, then: .next) }
                            update(block.id) { _ in .task(uuid, before, completed, when) }
                            insert([.task(UUID(), after, false, nil)], at: block.id, focusing: true)
                        }
                        return true
                    }, onDeleteAtStart: {
                        guard case .task(_, let text, _, _)? = self.block(block.id), text.isEmpty else { return false }
                        change("Delete") { remove(block.id, then: .previous) }
                        return true
                    }) }
                }

            case .frame(_, let children):
                HStack(alignment: .top, spacing: Style.Spacing.page) {
                    ForEach(children) { child in component(child) }
                }

            default:
                component(block)
        }
    }

    private func component(_ block: Block) -> some View {
        let ref: Reference? = switch block {
            case .artifact(let ref), .command(let ref), .document(let ref): ref
            case .text(_, let text): Self.reference(in: text)
            default: nil
        }
        return BlockCard(
            onSelect: { select(block.id) },
            onOpen: { if let ref { onOpenLink(.reference(ref)) } },
            onDrag: { drag(block.id) },
            onFrame: { cardFrames[block.id] = $0 }
        ) {
            if case .text = block, let ref { Card(ref: ref, style: .group, isSelected: selection == block.id) }
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

    private func locate(_ id: AnyHashable) -> (row: Int, child: Int?)? {
        for (index, block) in rows.enumerated() {
            if block.id == id { return (index, nil) }
            if case .frame(_, let children) = block, let child = children.firstIndex(where: { $0.id == id }) { return (index, child) }
        }
        return nil
    }

    private func block(_ id: AnyHashable) -> Block? {
        guard let location = locate(id) else { return nil }
        guard let child = location.child, case .frame(_, let children) = rows[location.row] else { return rows[location.row] }
        return children[child]
    }

    private func text(of id: AnyHashable) -> String {
        switch block(id) {
            case .text(_, let text)?, .task(_, let text, _, _)?: text
            default: ""
        }
    }

    private static func edits(_ block: Block) -> Bool {
        switch block {
            case .task: true
            case .text(_, let text): Markdown.Table(text) == nil && reference(in: text) == nil
            default: false
        }
    }

    private static func reference(in text: String) -> Reference? {
        let source = text as NSString
        guard let link = Markdown.scan(text).links.first, link.range.length == source.length else { return nil }
        return Reference.Link.reference(in: source.substring(with: link.url))
    }

    private func type(_ id: AnyHashable, _ text: String) {
        if typing?.id != id || Date.now.timeIntervalSince(typing?.at ?? .distantPast) > 2 { checkpoint("Typing") }
        typing = (id, .now)
        write(id, text)
    }

    private func enter(_ block: Block, from exit: ScintEditor.Exit) {
        if Self.edits(block) { focus = Focus(id: block.id, entry: exit) }
        else if case .frame(_, let children) = block, let first = children.first { select(first.id) }
        else { select(block.id) }
    }

    private func move(from id: AnyHashable, _ exit: ScintEditor.Exit) -> Bool {
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

    private func moveSelection(_ exit: ScintEditor.Exit) -> Bool {
        guard let selection, let location = locate(selection) else { return false }
        let rows = rows, target = location.row + (exit == .next ? 1 : -1)
        guard rows.indices.contains(target) else { return true }
        if location.child == nil, Self.edits(rows[location.row]) {
            if case .frame(_, let children) = rows[target], let first = children.first { select(first.id) }
            else { select(rows[target].id) }
        } else {
            enter(rows[target], from: exit)
        }
        return true
    }

    private func moveSideways(_ step: Int) -> Bool {
        guard let selection, let location = locate(selection), let child = location.child,
              case .frame(_, let children) = rows[location.row]
        else { return false }
        if children.indices.contains(child + step) { select(children[child + step].id) }
        return true
    }

    private func editSelection(opening: Bool) -> Bool {
        guard let selection, let block = block(selection) else { return false }
        if Self.edits(block) { select(nil); focus = resume }
        else if opening, let row = locate(selection).map({ rows[$0.row].id }) {
            select(nil)
            change("Insert") { insert([.text(UUID(), "")], at: row, focusing: true) }
        }
        else { select(nil) }
        return true
    }

    private func deleteSelection() -> Bool {
        guard let selection, let location = locate(selection) else { return false }
        let rows = rows
        let next: AnyHashable? = {
            if let child = location.child, case .frame(_, let children) = rows[location.row] {
                return children.indices.contains(child + 1) ? children[child + 1].id : children[child - 1].id
            }
            let row = rows.indices.contains(location.row + 1) ? location.row + 1 : location.row - 1
            guard rows.indices.contains(row) else { return nil }
            if case .frame(_, let children) = rows[row] { return children.first?.id }
            return rows[row].id == AnyHashable(tail) ? nil : rows[row].id
        }()
        change("Delete") { Self.replace(Self.removing(selection, from: blocks), in: document) }
        select(next)
        return true
    }

    private func drag(_ id: AnyHashable) -> NSItemProvider {
        dragged = id
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.block.identifier, visibility: .ownProcess) { $0(Data(), nil); return nil }
        return provider
    }

    private func aim(at point: CGPoint) -> (target: AnyHashable?, beside: Bool, line: CGRect)? {
        if let (id, frame) = cardFrames.first(where: { $0.value.contains(point) && point.x > $0.value.maxX - $0.value.width / 4 }) {
            return (id, true, CGRect(x: frame.maxX + 4, y: frame.minY, width: 3, height: frame.height))
        }
        let placed = rows.compactMap { row in rowFrames[row.id].map { (id: row.id, frame: $0) } }.sorted { $0.frame.minY < $1.frame.minY }
        guard let last = placed.last else { return nil }
        guard let index = placed.firstIndex(where: { point.y < $0.frame.midY }) else {
            return (nil, false, CGRect(x: last.frame.minX, y: last.frame.maxY + 4, width: last.frame.width, height: 3))
        }
        let above = index > 0 ? placed[index - 1].frame.maxY : placed[index].frame.minY - 8
        let frame = placed[index].frame
        return (placed[index].id, false, CGRect(x: frame.minX, y: (above + frame.minY) / 2 - 1.5, width: frame.width, height: 3))
    }

    private func drop(onto target: AnyHashable?, beside: Bool) -> Bool {
        guard let dragged, dragged != target, let moving = block(dragged) else { self.dragged = nil; return false }
        let component = { (block: Block) -> Bool in
            switch block {
                case .artifact, .command, .document: true
                case .text(_, let text): Self.reference(in: text) != nil
                default: false
            }
        }
        var placed = false
        let moved = Self.removing(dragged, from: blocks).flatMap { block -> [Block] in
            if block.id == target {
                placed = true
                return beside && component(moving) && component(block) ? [.frame(UUID(), [block, moving])] : [moving, block]
            }
            guard case .frame(let frame, var children) = block, let index = children.firstIndex(where: { $0.id == target }) else { return [block] }
            placed = true
            guard component(moving) else { return [moving, block] }
            children.insert(moving, at: beside ? index + 1 : index)
            return [.frame(frame, children)]
        }
        change("Move") { Self.replace(placed ? moved : moved + [moving], in: document) }
        self.dragged = nil
        return true
    }

    private static func removing(_ id: AnyHashable, from blocks: [Block]) -> [Block] {
        blocks.compactMap { block in
            guard block.id != id else { return nil }
            guard case .frame(let frame, let children) = block else { return block }
            let kept = children.filter { $0.id != id }
            return kept.count > 1 ? .frame(frame, kept) : kept.first
        }
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
        let document = document, blocks = blocks
        undoManager.registerUndo(withTarget: undoManager) { Self.restore(blocks, in: document, $0) }
        undoManager.setActionName(name)
    }

    private static func restore(_ blocks: [Block], in document: Reference, _ undoManager: UndoManager) {
        let current = ScintRuntime.Document.with(document, { $0.blocks }) ?? []
        undoManager.registerUndo(withTarget: undoManager) { restore(current, in: document, $0) }
        replace(blocks, in: document)
    }

    private func update(_ id: AnyHashable, _ change: (Block) -> Block) {
        ScintRuntime.Document.update(document) { document in
            guard let index = document.blocks.firstIndex(where: { $0.id == id }) else { return }
            document.update(change(document.blocks[index]), at: index)
        }
    }

    private func write(_ id: AnyHashable, _ text: String) {
        guard id == AnyHashable(tail) else {
            return update(id) { block in
                switch block {
                    case .text(let uuid, _): .text(uuid, text)
                    case .task(let uuid, _, let completed, let when): .task(uuid, text, completed, when)
                    default: block
                }
            }
        }
        ScintRuntime.Document.update(document) { $0.insert(.text(tail, text), at: nil) }
        tail = UUID()
    }

    private func delete(_ id: AnyHashable) {
        ScintRuntime.Document.update(document) { document in
            if let index = document.blocks.firstIndex(where: { $0.id == id }) { document.delete(at: index) }
        }
    }

    private func remove(_ id: AnyHashable, then exit: ScintEditor.Exit) {
        _ = move(from: id, exit)
        delete(id)
    }

    private func insert(_ blocks: [Block], at id: AnyHashable, splitting offset: Int? = nil, focusing: Bool = false) {
        var continued = false
        ScintRuntime.Document.update(document) { document in
            guard let index = document.blocks.firstIndex(where: { $0.id == id }) else { return document.insert(blocks, at: nil) }
            guard let offset, case .text(let uuid, let text) = document.blocks[index] else { return document.insert(blocks, at: index + 1) }
            let source = text as NSString, split = min(offset, source.length)
            let before = source.substring(to: split).trimmingCharacters(in: .newlines)
            let after = source.substring(from: split).trimmingCharacters(in: .newlines)
            continued = !after.isEmpty
            document.delete(at: index)
            document.insert((before.isEmpty ? [] : [.text(uuid, before)]) + blocks + (after.isEmpty ? [] : [.text(UUID(), after)]), at: index)
        }
        if focusing, let first = blocks.first { focus = Focus(id: first.id, entry: .next); return }
        let rows = rows
        guard let last = blocks.last?.id, let index = rows.firstIndex(where: { $0.id == last }) else { return }
        if rows.indices.contains(index + 1), case .text(_, let text) = rows[index + 1], text.isEmpty || continued {
            return enter(rows[index + 1], from: .next)
        }
        let line = UUID()
        ScintRuntime.Document.update(document) { document in
            document.insert(.text(line, ""), at: document.blocks.firstIndex { $0.id == last }.map { $0 + 1 })
        }
        focus = Focus(id: line, entry: .next)
    }
}
