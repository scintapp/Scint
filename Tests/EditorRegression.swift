import Foundation
import Observation

struct Artifact {}
struct Command {}
struct Reference: Hashable, Codable, Sendable {
    let id: UUID
    var kind: String = "material"
    init(_ id: UUID = UUID(), kind: String = "material") { self.id = id; self.kind = kind }
    var type: Any.Type { kind == "artifact" ? Artifact.self : kind == "command" ? Command.self : Material.self }
    enum Link {
        static func reference(in value: String) -> Reference? {
            guard let url = URL(string: value), url.scheme == "scint", let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            return Reference(id)
        }
        static func markdown(for ref: Reference, name: String? = nil) -> String? { "[\(name ?? "Reference")](scint://material/\(ref.id))" }
    }
}
@MainActor @Observable final class EditorTestStore {
    static let shared = EditorTestStore()
    var values: [Reference: Material] = [:]
}
extension Material {
    @MainActor static var store: [Reference: Material] {
        get { EditorTestStore.shared.values }
        set { EditorTestStore.shared.values = newValue }
    }
    @MainActor static var writes = 0
    @MainActor static func with<T>(_ ref: Reference, _ body: (Material) -> T) -> T? { store[ref].map(body) }
    @MainActor static func update<T>(_ ref: Reference, _ body: (inout Material) -> T) -> T? {
        guard var value = store[ref] else { return nil }
        let result = body(&value)
        if value.blocks != store[ref]!.blocks { writes += 1 }
        store[ref] = value; return result
    }
}
@MainActor final class RecordingRenderer: TextRendering {
    var storage: String
    var replacements: [(Range<Int>, String)] = []
    var selection: (Int, Int)?
    init(_ text: String) { storage = text }
    func replace(_ range: Range<Int>, with text: String) {
        replacements.append((range, text)); storage = (storage as NSString).replacingCharacters(in: NSRange(range), with: text)
    }
    func select(anchor: Int, head: Int) { selection = (anchor, head) }
    func clearSelection() { selection = nil }
}
@main struct EditorRegression {
    @MainActor static var assertions = 0
    @MainActor static func expect(_ value: @autoclosure () -> Bool, _ message: String, line: Int = #line) {
        assertions += 1; precondition(value(), "EditorRegression:\(line): \(message)")
    }
    @MainActor static func make(_ blocks: [Material.Block]) -> Editor {
        let ref = Reference(); Material.store[ref] = Material(blocks: blocks); return Editor(material: ref)
    }
    @MainActor static func invariant(_ editor: Editor) {
        if case .empty = editor.position { expect(editor.blocks.isEmpty, "empty position has no phantom block") }
        else { expect(!editor.blocks.isEmpty, "nonempty position targets real blocks") }
        for pair in zip(editor.blocks, editor.blocks.dropFirst()) {
            if case .text = pair.0, case .text = pair.1 { fatalError("Adjacent text blocks") }
        }
    }
    @MainActor static func roundTrip(_ editor: Editor, _ action: () -> Void) {
        let before = editor.blocks, position = editor.position, count = editor.undoStack.count
        action(); invariant(editor)
        let after = editor.blocks, end = editor.position
        if editor.undoStack.count > count {
            editor.reconcileBlocks(); editor.undo()
            expect(editor.blocks == before && editor.position == position, "undo restores material and position")
            editor.redo(); expect(editor.blocks == after && editor.position == end, "redo restores material and position")
        }
    }
    @MainActor static func main() {
        if CommandLine.arguments.contains("--invalid-undo") {
            let id = UUID(), e = make([.text(id, "a")]); e.type("b")
            Material.update(e.material) { $0.update(.text(id, "aX"), at: 0) }
            e.reconcileText(id: id, prefix: 1, removed: 1, inserted: 1)
            e.undo(); fatalError("Invalid undo returned successfully")
        }
        primitives(); positions(); boundaries(); boundaryMatrix(); emptyMaterials(); history(); reconcile(); menusAndLinks(); referenceHistory(); randomSequences()
        print("Editor regression passed: \(assertions) assertions, 500 random command sequences")
    }
    @MainActor static func primitives() {
        let a = UUID(), b = UUID(), task = Material.Block.task(UUID(), "Task", false)
        let e = make([.text(a, "abc"), task, .text(b, "untouched")]), before = Material.writes
        let r = RecordingRenderer("abc"); e.attach(r, to: a)
        let position = e.position
        expect(e.insert("\r\nx\ry", in: a, at: 1), "insert")
        expect(e.string(a) == "a\nx\nybc" && r.storage == e.string(a), "normalization, synchronous renderer")
        expect(r.replacements.last!.0 == 1..<1 && r.replacements.last!.1 == "\nx\ny", "exact renderer patch")
        expect(e.delete(in: a, range: 1..<5), "delete")
        expect(e.string(a) == "abc" && e.blocks[1] == task && e.string(b) == "untouched", "isolated text edits")
        expect(e.position == position, "primitives preserve position")
        let writes = Material.writes
        expect(!e.insert("", in: a, at: 0) && !e.insert("x", in: a, at: 99), "bad insertion")
        expect(!e.insert("x", in: task.id, at: 0) && !e.insert("x", in: UUID(), at: 0), "bad targets")
        expect(!e.delete(in: a, range: 0..<99) && !e.delete(in: a, range: 0..<0), "bad deletion")
        expect(!e.insert(task, after: nil) && !e.insert(.text(UUID(), ""), after: UUID()), "duplicate and missing predecessor")
        expect(Material.writes == writes && writes == before + 2, "invalid primitives write nothing")
    }
    @MainActor static func positions() {
        for grapheme in ["e\u{301}", "👨‍👩‍👧", "🇧🇷"] {
            let id = UUID(), e = make([.text(id, grapheme)])
            e.moveLeft(extending: false); expect(e.position == .text(id: id, anchor: 0, head: 0), "one grapheme left")
            e.moveRight(extending: true); expect(e.position == .text(id: id, anchor: 0, head: grapheme.utf16.count), "one grapheme extended")
            e.moveLeft(extending: false); expect(e.position == .text(id: id, anchor: 0, head: 0), "collapse left")
            e.place(.text(id: id, anchor: 1, head: 1)); expect(e.position == .text(id: id, anchor: 0, head: 0), "snap grapheme")
        }
        let id = UUID(), card = Material.Block.task(UUID(), "t", false), writes = Material.writes
        let e = make([.text(id, "abc"), card]); expect(e.position == .blocks(anchor: card.id, head: card.id), "initial card")
        e.place(.text(id: card.id, anchor: 0, head: 0)); e.place(.blocks(anchor: UUID(), head: id))
        expect(e.position == .blocks(anchor: card.id, head: card.id) && Material.writes == writes, "invalid place and initialization do not write")
        switch e.position { case .empty: break; case .text: break; case .blocks: break }
    }
    @MainActor static func boundaries() {
        for text in ["", "abc"] {
            for forward in [false, true] {
                let id = UUID(), card = Material.Block.task(UUID(), "t", false)
                let e = make(forward ? [.text(id, text), card] : [card, .text(id, text)])
                let offset = forward ? text.utf16.count : 0
                e.place(.text(id: id, anchor: offset, head: offset))
                roundTrip(e) { if forward { e.deleteForward() } else { e.deleteBackward() } }
                expect(e.position == .blocks(anchor: card.id, head: card.id), "boundary selects card")
                expect(e.blocks.count == (text.isEmpty ? 1 : 2), "only empty boundary text removed")
            }
        }
        for pair in [("a", "b"), ("a\n", "b"), ("", "b"), ("a", "")] {
            let a = UUID(), b = UUID(), card = Material.Block.task(UUID(), "t", false)
            let e = make([.text(a, pair.0), card, .text(b, pair.1)])
            e.place(.blocks(anchor: card.id, head: card.id))
            roundTrip(e) { e.removeSelectedBlocks() }
            let separator = pair.0.isEmpty || pair.0.hasSuffix("\n") || pair.1.isEmpty ? "" : "\n"
            expect(e.string(a) == pair.0 + separator + pair.1, "merge separator")
            expect(e.position == .text(id: a, anchor: pair.0.utf16.count + separator.utf16.count, head: pair.0.utf16.count + separator.utf16.count), "join caret")
        }
        let id = UUID(), e = make([.text(id, "head\n\ntail")])
        e.place(.text(id: id, anchor: 5, head: 5)); roundTrip(e) { e.insertCard(.task(UUID(), "t", false)) }
        expect(e.blocks.count == 3 && e.string(id) == "head", "split trims head newline")
        if case .text(_, let tail) = e.blocks.last! { expect(tail == "tail", "split trims tail newline") }
        e.selectAll(); roundTrip(e) { e.removeSelectedBlocks() }; expect(e.blocks.count == 1, "remove all repairs empty document")
        let card = Material.Block.task(UUID(), "t", false), c = make([card])
        roundTrip(c) { c.newline() }; expect(c.blocks.count == 2 && c.isTextPosition, "newline creates text after card")
    }
    @MainActor static func emptyMaterials() {
        let e = make([]), writes = Material.writes
        expect(e.position == .empty, "empty input has explicit position")
        e.reconcileBlocks(); e.selectAll(); e.escape(); e.moveLeft(extending: false); e.deleteBackward()
        expect(e.position == .empty && Material.writes == writes, "empty navigation and reconciliation never write")
        roundTrip(e) { e.type("first") }
        e.undo(); expect(e.blocks.isEmpty && e.position == .empty, "undo first typing restores empty document")
        roundTrip(e) { e.newline() }
        e.undo(); roundTrip(e) { e.insertCard(.task(UUID(), "first", false)) }
        Material.update(e.material) { $0.blocks = [] }; e.reconcileBlocks()
        expect(e.position == .empty, "external clear reconciles without inventing content")
    }
    @MainActor static func boundaryMatrix() {
        let a = UUID(), b = UUID(), card = Material.Block.task(UUID(), "t", false)
        let e = make([.text(a, "alpha beta"), card, .text(b, "tail")])
        for (id, at, direction, expected) in [(a, 0, Editor.Direction.up, a as AnyHashable), (a, 10, .down, card.id), (b, 0, .up, card.id), (b, 4, .down, b as AnyHashable)] {
            e.place(.text(id: id, anchor: at, head: at)); let before = e.position, writes = Material.writes
            if direction == .up { e.moveLeft(extending: true) } else { e.moveRight(extending: true) }
            expect(e.position == before, "extending never crosses boundary")
            if direction == .up { e.moveLeft(extending: false) } else { e.moveRight(extending: false) }
            expect(e.position.id == expected && Material.writes == writes, "boundary movement selects neighbor without writes")
        }
        for direction in [Editor.Direction.up, .down] {
            e.place(.blocks(anchor: card.id, head: card.id)); e.stepBlock(direction, extending: false)
            expect(e.position == (direction == .up ? .text(id: a, anchor: 10, head: 10) : .text(id: b, anchor: 0, head: 0)), "block movement enters neighboring text")
            e.place(.blocks(anchor: card.id, head: card.id)); e.stepBlock(direction, extending: true)
            expect(e.position == .blocks(anchor: card.id, head: direction == .up ? a : b), "block extension preserves anchor")
            e.newline(); expect(e.position == .blocks(anchor: direction == .up ? a : b, head: direction == .up ? a : b), "multi-block newline collapses to head")
        }
        e.place(.blocks(anchor: a, head: a)); e.newline()
        expect(e.position == .text(id: a, anchor: 10, head: 10), "newline enters selected text at end")
        e.place(.blocks(anchor: card.id, head: card.id)); let writes = Material.writes; e.newline()
        expect(e.position == .text(id: b, anchor: 0, head: 0) && Material.writes == writes, "newline reuses next text")
        e.selectAll(); expect(e.position == .text(id: b, anchor: 0, head: 4), "first select all selects text")
        e.selectAll(); expect(e.position == .blocks(anchor: a, head: b), "second select all selects document")
        e.escape(); expect(e.position == .blocks(anchor: b, head: b), "escape collapses block selection")
        e.type("ignored"); expect(e.string(b) == "tail", "typing on blocks is no-op")
        e.place(.text(id: a, anchor: 0, head: 0)); e.moveWordRight(extending: true)
        expect(e.position == .text(id: a, anchor: 0, head: 5), "word movement")
        e.moveRight(extending: false); expect(e.position == .text(id: a, anchor: 5, head: 5), "right collapses selection")
        roundTrip(e) { e.deleteWordBackward() }
        let list = UUID(), l = make([.text(list, "- item")]); roundTrip(l) { l.indent(by: 1) }
        expect(l.string(list) == "  - item", "indent edits prefix only")
        roundTrip(l) { l.indent(by: -1) }
        for offset in [0, 3] {
            let id = UUID(), editor = make([.text(id, "abc")]); editor.place(.text(id: id, anchor: offset, head: offset))
            roundTrip(editor) { editor.insertCard(.task(UUID(), "t", false)) }
            expect(editor.blocks.count == 2 && editor.string(id) == "abc", "edge card insertion does not split")
        }
        let c = make([card]); roundTrip(c) { c.replaceCard(card.id, with: .task(card.id.base as! UUID, "edited", true)) }
        let reference = Reference(), r = make([.text(UUID(), " ")]); r.type("@"); r.type("q")
        roundTrip(r) { r.commitReference(reference, name: "Name") }
        expect(r.selectedLink == nil, "menu reference commit ends at caret")
        let close = make([.text(UUID(), " ")]); close.type("/"); let w = Material.writes
        close.escape(); expect(close.trigger == nil && Material.writes == w, "escape closes trigger without write")
    }
    @MainActor static func history() {
        let id = UUID(), e = make([.text(id, "")]); var time = 0.0; e.clock = { time }
        for c in "hello world" { e.type(String(c)) }; expect(e.undoStack.count == 2, "word coalescing")
        e.moveLeft(extending: false); e.type("x"); expect(e.undoStack.count == 3, "movement breaks group")
        time += 1.1; e.type("y"); expect(e.undoStack.count == 4, "time breaks group")
        e.undo(); e.type("z"); expect(e.redoStack.isEmpty && !e.undoManager.canRedo, "new edit clears redo")
        let a = Material.Block.task(UUID(), "a", false), b = Material.Block.task(UUID(), "b", false), c = make([a,b])
        c.removeSelectedBlocks(); let external = Material.Block.task(UUID(), "external", false)
        Material.update(c.material) { $0.insert(external, at: 0) }; c.reconcileBlocks(); c.undo()
        expect(c.blocks == [external,a,b], "undo uses predecessor and survives reconciliation")
    }
    @MainActor static func reconcile() {
        let id = UUID(), e = make([.text(id, "abc")]); e.type("d")
        Material.update(e.material) { $0.update(.text(id, "Xabcd"), at: 0) }
        e.reconcileText(id: id, prefix: 0, removed: 0, inserted: 1)
        expect(e.position == .text(id: id, anchor: 5, head: 5), "external insertion shifts caret")
        e.undo(); expect(e.string(id) == "Xabc", "undo rebased text")
        let before = e.position; e.reconcileBlocks(); e.reconcileText(id: id, prefix: 0, removed: 0, inserted: 0)
        expect(e.position == before, "no change reconcile is no-op")
    }
    @MainActor static func menusAndLinks() {
        let id = UUID(), e = make([.text(id, "a ")]); e.type("/"); e.type("t")
        expect(e.trigger != nil && e.query == "t", "trigger query")
        roundTrip(e) { e.commitTask("Task", completed: false) }
        let ref = Reference(), markdown = Reference.Link.markdown(for: ref)!, linkID = UUID()
        let links = make([.text(linkID, markdown + " [Web](https://example.com)")])
        links.place(.text(id: linkID, anchor: markdown.utf16.count, head: 0))
        expect(links.selectedReference == ref, "reverse link selection")
        var opens = 0; links.onOpenLink = { _ in opens += 1 }; let pos = links.position, before = links.blocks
        links.open(.reference(ref)); expect(opens == 1 && links.position == pos && links.blocks == before, "open is pure callback")
        links.moveLeft(extending: false); expect(links.selectedLink == nil, "caret is not link selection")
        expect(links.linkRange(in: linkID, containing: markdown.utf16.count) == nil, "exclusive link end")
        let t = make([.text(UUID(), "word")]); t.type("/"); expect(t.trigger == nil, "no trigger inside word")
    }
    @MainActor static func referenceHistory() {
        let a = Reference(), b = Reference(), e = make([.material(a)])
        roundTrip(e) { e.replaceCard(a, with: .material(b)) }
        expect(e.selectedReference == b, "replacement keeps the entire new reference")
        expect(e.undoStack.last?.steps.count == 2, "reference replacement records removal and insertion")
        e.undo(); expect(e.selectedReference == a && e.blocks == [.material(a)], "undo restores original reference intact")
        let uuid = UUID(), artifact = Reference(uuid, kind: "artifact"), command = Reference(uuid, kind: "command")
        let distinct = make([.artifact(artifact)])
        expect(distinct.insert(.command(command), after: artifact), "distinct References are not collapsed to UUID")
        let id = UUID(), inserted = make([.text(id, "")]); inserted.type("abc")
        Material.update(inserted.material) { $0.update(.text(id, "Xabc"), at: 0) }
        inserted.reconcileText(id: id, prefix: 0, removed: 0, inserted: 1)
        inserted.undo(); expect(inserted.string(id) == "X", "external insertion at undo span start survives undo")
        let left = Material.Block.task(UUID(), "left", false), middle = Material.Block.task(UUID(), "middle", false), right = Material.Block.task(UUID(), "right", false)
        let removed = make([left, middle, right]); removed.place(.blocks(anchor: middle.id, head: middle.id))
        Material.update(removed.material) { $0.delete(at: 1) }; removed.reconcileBlocks()
        expect(removed.position == .blocks(anchor: right.id, head: right.id), "external removal uses former index")
        removed.place(.blocks(anchor: left.id, head: right.id))
        Material.update(removed.material) { $0.delete(at: 0) }; removed.reconcileBlocks()
        expect(removed.position == .blocks(anchor: right.id, head: right.id), "external removal preserves surviving endpoint")
        let wordID = UUID(), words = make([.text(wordID, "one two")]); words.place(.text(id: wordID, anchor: 0, head: 0))
        roundTrip(words) { words.deleteWordForward() }
        expect(words.string(wordID) == " two", "word forward deletion")
        let batch = make([.text(UUID(), "abc abc")]), batchID = batch.blocks[0].id
        roundTrip(batch) {
            batch.beginGroup()
            batch.replace(in: batchID, range: 4..<7, with: "xyz")
            batch.replace(in: batchID, range: 0..<3, with: "xyz")
            batch.endGroup()
        }
        expect(batch.undoStack.count == 1, "replace all is one group")
    }
    @MainActor static func randomSequences() {
        var seed: UInt64 = 0x5C17
        func random(_ count: Int) -> Int { seed = seed &* 6364136223846793005 &+ 1; return Int((seed >> 32) % UInt64(count)) }
        for _ in 0..<500 {
            let fixture: [Material.Block] = (0..<random(6)).map { index in
                index % 2 == 0 ? .text(UUID(), ["seed", "", "e\u{301}🇧🇷"][random(3)]) : .task(UUID(), "seed task", false)
            }
            let e = make(fixture), original = e.blocks, start = e.position
            if case .blocks = e.position { e.newline() } else { e.type("x") }
            for _ in 0..<40 {
                switch random(10) {
                case 0: e.type(["a", "🇧🇷", "e\u{301}"][random(3)])
                case 1: e.deleteBackward()
                case 2: e.deleteForward()
                case 3: e.newline()
                case 4: e.moveLeft(extending: random(2) == 0)
                case 5: e.moveRight(extending: random(2) == 0)
                case 6: e.insertCard(.task(UUID(), "t", false))
                case 7: e.selectAll()
                case 8:
                    if !e.blocks.isEmpty { e.moveBlock(e.blocks[random(e.blocks.count)].id, after: random(2) == 0 ? nil : e.blocks.last?.id) }
                default: e.escape()
                }
                invariant(e); e.reconcileBlocks()
            }
            let final = e.blocks, end = e.undoStack.last?.after
            while e.undoManager.canUndo { e.undo(); invariant(e) }
            expect(e.blocks == original, "random undo restores original material")
            if !e.redoStack.isEmpty { expect(e.position == start, "random undo restores initial position") }
            while e.undoManager.canRedo { e.redo(); invariant(e) }
            expect(e.blocks == final, "random redo restores final material")
            if let end { expect(e.position == end, "random redo restores final command position") }
        }
    }
}
