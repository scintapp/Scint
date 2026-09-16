import AppKit
import SwiftUI

// Compiles the production editor against stand-ins for the runtime store, design tokens and SwiftUI components,
// then drives a real TextKit 2 text view in an offscreen window.

// MARK: Stand-ins

struct Artifact {}
struct Command {}
struct Reference: Hashable, Codable, Sendable {
    let id: UUID
    var kind: String
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

@MainActor enum Store { static var materials: [Reference: Material] = [:]; static var writes = 0 }
extension Material {
    @MainActor static func with<R>(_ ref: Reference, _ body: (Material) -> R) -> R? { Store.materials[ref].map(body) }
    @MainActor @discardableResult static func update<R>(_ ref: Reference, _ body: (inout Material) -> R) -> R? {
        guard var value = Store.materials[ref] else { return nil }
        let result = body(&value); Store.materials[ref] = value; Store.writes += 1; return result
    }
}

enum Typography {
    enum Scale { static let hiddenSyntax: CGFloat = 0.1 }
    enum Prose {
        static var appKitText: NSFont { .systemFont(ofSize: 14) }
        static var appKitCode: NSFont { .monospacedSystemFont(ofSize: 13, weight: .regular) }
        static var appKitSyntaxHidden: NSFont { .systemFont(ofSize: Scale.hiddenSyntax) }
        static func appKitHeading(_ level: Int) -> NSFont { .systemFont(ofSize: CGFloat(26 - level * 3), weight: .semibold) }
        static var paragraphStyle: NSParagraphStyle { let p = NSMutableParagraphStyle(); p.paragraphSpacing = 6; return p }
        static func headingParagraphStyle(_ level: Int) -> NSParagraphStyle { paragraphStyle }
        static func listParagraphStyle(indent: CGFloat, hanging: CGFloat) -> NSParagraphStyle { NSMutableParagraphStyle() }
        static var quoteParagraphStyle: NSParagraphStyle { NSMutableParagraphStyle() }
    }
}
enum Style {
    enum Foreground { static let primary = Color.white }
    enum Tint { static let accent = Color.blue }
    enum Background { static let overlay = Color.gray }
    enum Opacity { static let washed = 0.1, faint = 0.3, muted = 0.6, strong = 0.9 }
    enum Spacing {
        static let sm: CGFloat = 4, xs: CGFloat = 2, lg: CGFloat = 12, markdownListInset: CGFloat = 16, listIndent: CGFloat = 16
        static let menuWidth: CGFloat = 300, menuListHeight: CGFloat = 300, menuFormHeight: CGFloat = 200
    }
    enum Dimension { static let markdownQuoteBar: CGFloat = 3, markdownBullet: CGFloat = 4 }
}
enum MarkdownDecoration { static func code(_ rect: CGRect) {} }
enum CardStyle { case group }
struct Card: View { let ref: Reference; let style: CardStyle; var isSelected = false; var body: some View { Text("card").frame(height: 40) } }
struct TextBlock: View { let content: String; var body: some View { Text(content) } }
struct MaterialBlock: View {
    let block: Material.Block
    var isSelected = false
    var body: some View {
        if case .task(_, let text, _) = block, text.count > 40 {
            Text(text).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        } else {
            Text("block").frame(maxWidth: .infinity, minHeight: 44)
        }
    }
}
@MainActor @Observable final class ReferenceSelection { static let shared = ReferenceSelection(); var selected: Reference? }
struct MenuPanelContent {
    init(controller: MenuController, onSelect: @escaping (MenuItem) -> Void, onCancel: @escaping () -> Void, onCommit: @escaping () -> Void) {}
}
@MainActor final class MenuPanelPresenter {
    var onResignKey: (() -> Void)?
    var onEscape: (() -> Void)?
    var presented = 0, dismissed = 0
    func present(_ content: MenuPanelContent, size: CGSize, anchor: CGRect, in host: NSWindow) { presented += 1 }
    func dismiss() { dismissed += 1 }
}
@MainActor enum ScintEditorMenu {
    static let menu: [MenuItem] = [.command(id: "new-task", label: "Task", icon: nil, keywords: ["task"], opens: .task)]
    static func search(_ query: String, kind: MenuKind) -> [MenuItem] { [] }
    static func form(for block: Material.Block) -> (MenuFormKind, MenuFormValues)? {
        if case .task(_, let text, let done) = block { return (.task, MenuFormValues(primary: text, completed: done)) }
        return nil
    }
    static func commit(_ outcome: MenuOutcome, editor: ScintEditor) {
        if case .form(.task, let values) = outcome.choice, outcome.isInserting {
            editor.insert(.task(UUID(), values.primary, values.completed), replacing: outcome.replacementRange)
        }
    }
}

// MARK: Tests

@MainActor var failures = 0
@MainActor func check(_ condition: Bool, _ message: String, line: Int = #line) {
    if !condition { failures += 1 }
    print(condition ? "PASS" : "FAIL", "[\(line)]", message)
}
@MainActor func spin() { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }

@main struct EditorRegression {
    @MainActor static func main() {
        _ = NSApplication.shared
        let card = UUID(), first = UUID(), second = UUID()
        let ref = Reference()
        var material = Material()
        material.insert([.text(first, "Hello"), .task(card, "Do it", false), .text(second, "World")], at: 0)
        Store.materials[ref] = material
        func blocks() -> [Material.Block] { Store.materials[ref]?.blocks ?? [] }
        func content(_ blocks: [Material.Block]) -> [String] {
            blocks.map { block in
                switch block { case .text(_, let text): text; case .task(_, let text, _): "task:" + text; default: "ref" }
            }
        }

        let editor = ScintEditor(ref, autofocus: true)
        let scroll = EditorScrollView(editor, sizing: .fitsContent)
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 480, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        scroll.frame = CGRect(x: 0, y: 0, width: 480, height: 600)
        window.contentView = scroll
        window.makeFirstResponder(editor)
        spin()

        // Rendering
        check(editor.string == "Hello\n\u{FFFC}\nWorld", "renders blocks with card separators: \(editor.string.debugDescription)")
        check(editor.textLayoutManager != nil, "uses TextKit 2")
        let initialHeight = editor.height(for: 480)
        check(initialHeight > 0, "height \(initialHeight)")
        editor.textLayout.textViewportLayoutController.layoutViewport()
        window.displayIfNeeded()
        let cardView = editor.card(card)?.view
        check(cardView != nil, "card attachment view loaded")
        check((cardView?.frame.height ?? 0) >= 44, "card view height \(cardView?.frame.height ?? 0)")
        check(cardView?.superview != nil, "card view installed in view hierarchy")

        // Typing writes the material, keeping ids
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        editor.insertText("!", replacementRange: NSRange(location: NSNotFound, length: 0))
        check(blocks() == [.text(first, "Hello"), .task(card, "Do it", false), .text(second, "World!")], "typing saves: \(blocks())")
        spin()

        // Undo restores
        editor.undoManager?.undo()
        spin()
        check(blocks() == [.text(first, "Hello"), .task(card, "Do it", false), .text(second, "World")], "undo typing: \(blocks())")
        check(editor.string == "Hello\n\u{FFFC}\nWorld", "undo text: \(editor.string.debugDescription)")

        // Deleting the card rejoins lines; undo brings the card back
        editor.setSelectedRange(NSRange(location: 6, length: 1))
        editor.deleteBackward(nil)
        spin()
        check(editor.string == "Hello\nWorld", "card delete rejoins: \(editor.string.debugDescription)")
        check(blocks() == [.text(first, "Hello\nWorld")], "card delete saves: \(blocks())")
        editor.undoManager?.undo()
        spin()
        check(editor.string == "Hello\n\u{FFFC}\nWorld", "undo card delete text: \(editor.string.debugDescription)")
        check(content(blocks()) == ["Hello", "task:Do it", "World"] && blocks()[0].id == AnyHashable(first) && blocks()[1].id == AnyHashable(card), "undo card delete saves: \(blocks())")
        editor.undoManager?.redo()
        spin()
        check(editor.string == "Hello\nWorld", "redo card delete: \(editor.string.debugDescription)")
        editor.undoManager?.undo()
        spin()

        // Typing right after a card starts a new line
        editor.setSelectedRange(NSRange(location: 7, length: 0))
        editor.insertText("x", replacementRange: NSRange(location: NSNotFound, length: 0))
        check(editor.string == "Hello\n\u{FFFC}\nx\nWorld", "typing after card: \(editor.string.debugDescription)")
        check(content(blocks()) == ["Hello", "task:Do it", "x\nWorld"], "typing after card saves: \(blocks())")
        spin()
        editor.undoManager?.undo(); spin()

        // Slash menu inserts a task card in the middle of text
        editor.setSelectedRange(NSRange(location: 3, length: 0))
        editor.insertText("\n", replacementRange: NSRange(location: NSNotFound, length: 0))
        editor.insertText("/", replacementRange: NSRange(location: NSNotFound, length: 0))
        check(editor.menuController.isOpen && editor.presenter.presented > 0, "slash opens menu")
        editor.insertText("ta", replacementRange: NSRange(location: NSNotFound, length: 0))
        check(editor.menuController.query == "ta", "query tracks typing: \(editor.menuController.query)")
        editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        check(editor.menuController.isOpen && editor.menuController.kind == .create(.task), "return opens task form: \(editor.menuController.kind)")
        editor.menuController.formPrimary = "New task"
        let outcome = editor.menuController.commit()
        check(outcome != nil, "form commits")
        if let outcome { ScintEditorMenu.commit(outcome, editor: editor) }
        check(editor.string == "Hel\n\u{FFFC}\nlo\n\u{FFFC}\nWorld", "task inserted on its own line: \(editor.string.debugDescription)")
        let saved = blocks()
        check(saved.count == 5, "task saved: \(saved)")
        if saved.count == 5, case .task(_, let text, _) = saved[1] { check(text == "New task", "task text") }
        spin()

        // Tab and Shift-Tab indent list items
        editor.setSelectedRange(NSRange(location: 0, length: (editor.string as NSString).length))
        editor.insertText("- item", replacementRange: NSRange(location: NSNotFound, length: 0))
        check(blocks() == [.text(first, "- item")], "select all + type replaces everything, cards included: \(blocks())")
        editor.doCommand(by: #selector(NSResponder.insertTab(_:)))
        check(editor.string == "  - item", "tab indents: \(editor.string.debugDescription)")
        editor.doCommand(by: #selector(NSResponder.insertTab(_:)))
        check(editor.string == "    - item" && editor.selectedRange().location == 10, "tab indents again: \(editor.string.debugDescription) \(editor.selectedRange())")
        editor.doCommand(by: #selector(NSResponder.insertBacktab(_:)))
        editor.doCommand(by: #selector(NSResponder.insertBacktab(_:)))
        editor.doCommand(by: #selector(NSResponder.insertBacktab(_:)))
        check(editor.string == "- item" && editor.selectedRange().location == 6, "backtab outdents to the margin: \(editor.string.debugDescription) \(editor.selectedRange())")
        editor.doCommand(by: #selector(NSResponder.insertTab(_:)))
        spin()

        // Styling: headings get the heading font
        editor.setSelectedRange(NSRange(location: 0, length: (editor.string as NSString).length))
        editor.insertText("# Title\nbody", replacementRange: NSRange(location: NSNotFound, length: 0))
        check(editor.selectedRange().location == 12, "caret after typing stays put: \(editor.selectedRange())")
        spin()
        check(editor.selectedRange().location == 12, "caret after styling stays put: \(editor.selectedRange())")
        let font = editor.textStorage?.attribute(.font, at: 3, effectiveRange: nil) as? NSFont
        check(font?.pointSize == Typography.Prose.appKitHeading(1).pointSize, "heading styled: \(String(describing: font?.pointSize))")
        let bodyFont = editor.textStorage?.attribute(.font, at: 9, effectiveRange: nil) as? NSFont
        check(bodyFont?.pointSize == 14, "body styled: \(String(describing: bodyFont?.pointSize))")

        // External change reloads and clears undo
        Material.update(ref) { material in material.delete(at: 0); material.insert(.text(first, "From elsewhere"), at: 0) }
        editor.load(blocks())
        check(editor.string == "From elsewhere", "external load: \(editor.string.debugDescription)")
        check(editor.undoManager?.canUndo == false, "external load clears undo")
        let writes = Store.writes
        editor.load(blocks())
        check(Store.writes == writes, "loading own state does not write")

        // Empty material
        let emptyRef = Reference()
        Store.materials[emptyRef] = Material()
        let empty = ScintEditor(emptyRef, autofocus: false)
        empty.insertText("a", replacementRange: NSRange(location: NSNotFound, length: 0))
        check(Store.materials[emptyRef]?.blocks.count == 1, "typing into empty material creates a text block")
        empty.deleteBackward(nil)
        check(Store.materials[emptyRef]?.blocks.isEmpty == true, "deleting everything leaves no blocks")

        // Round trips
        let cardA = Material.Block.task(UUID(), "A", false), cardB = Material.Block.task(UUID(), "B", true)
        for sample: [Material.Block] in [
            [], [cardA], [cardA, cardB], [.text(UUID(), "x"), cardA], [cardA, .text(UUID(), "\nx\n")],
            [.text(UUID(), "a\n"), cardA, .text(UUID(), "\nb"), cardB, .text(UUID(), "c")],
        ] {
            let rendered = ScintEditor.render(sample)
            check(ScintEditor.blocks(in: rendered, reusing: sample) == sample, "round trip \(sample.count) blocks: \(rendered.string.debugDescription)")
        }

        // Second document: interactions
        let other = Reference(), noted = Reference(), task = UUID()
        var second2 = Material()
        second2.insert([.material(noted), .text(UUID(), "a/b"), .task(task, "Ship", false)], at: 0)
        Store.materials[other] = second2
        let doc = ScintEditor(other, autofocus: true)
        let docScroll = EditorScrollView(doc, sizing: .fitsContent)
        docScroll.frame = CGRect(x: 0, y: 0, width: 480, height: 400)
        window.contentView = docScroll
        window.makeFirstResponder(doc)
        spin()
        func blocks2() -> [Material.Block] { Store.materials[other]?.blocks ?? [] }
        check(doc.string == "\u{FFFC}\na/b\n\u{FFFC}", "second doc renders: \(doc.string.debugDescription)")

        // Clicking a card selects it and publishes its reference
        let click = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        if let noteCard = doc.card(noted) { doc.click(noteCard, with: click) }
        check(doc.selectedRange() == NSRange(location: 0, length: 1), "click selects card: \(doc.selectedRange())")
        check(doc.card(noted)?.isSelected == true, "card shows selected")
        check(ReferenceSelection.shared.selected == noted, "card reference published")

        // Return on a selected card moves past it instead of replacing it
        doc.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        check(doc.string == "\u{FFFC}\na/b\n\u{FFFC}" && doc.selectedRange() == NSRange(location: 1, length: 0), "return on card keeps it: \(doc.selectedRange())")
        check(doc.card(noted)?.isSelected == false && ReferenceSelection.shared.selected == nil, "deselecting clears card selection")

        // Space on a selected task card opens its edit form
        doc.setSelectedRange(NSRange(location: 6, length: 1))
        doc.insertText(" ", replacementRange: NSRange(location: NSNotFound, length: 0))
        check(doc.string == "\u{FFFC}\na/b\n\u{FFFC}" && doc.menuController.kind == .update(.task) && doc.menuController.formPrimary == "Ship", "space edits task card: \(doc.menuController.kind)")
        doc.menuController.formPrimary = "Shipped"; doc.menuController.formCompleted = true
        if let outcome = doc.menuController.commit() {
            doc.replaceCard(outcome.target, with: .task(task, doc.menuController.formPrimary, doc.menuController.formCompleted))
        }
        check(blocks2().last == .task(task, "Shipped", true), "task card replaced in place: \(blocks2())")
        doc.menuController.close()

        // Slash in the middle of a word does not open the menu; after a space it does; backspace closes it
        doc.setSelectedRange(NSRange(location: 3, length: 0))
        doc.insertText("/", replacementRange: NSRange(location: NSNotFound, length: 0))
        check(!doc.menuController.isOpen, "mid-word slash stays text")
        doc.insertText(" ", replacementRange: NSRange(location: NSNotFound, length: 0))
        doc.insertText("@", replacementRange: NSRange(location: NSNotFound, length: 0))
        check(doc.menuController.isOpen && doc.menuController.kind == .dynamic, "@ after space opens dynamic menu")
        doc.deleteBackward(nil)
        check(!doc.menuController.isOpen, "deleting the trigger closes the menu")
        doc.insertText("@", replacementRange: NSRange(location: NSNotFound, length: 0))
        doc.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        check(!doc.menuController.isOpen && doc.string.contains("@"), "escape closes menu, keeps text")
        spin()

        // Deleting cards at the edges takes their separator
        doc.setSelectedRange(NSRange(location: 0, length: 1))
        doc.deleteBackward(nil)
        check(!doc.string.hasPrefix("\n") && blocks2().first.map { if case .text = $0 { true } else { false } } == true, "deleting first card: \(doc.string.debugDescription)")
        let end = (doc.string as NSString).length
        doc.setSelectedRange(NSRange(location: end - 1, length: 1))
        doc.deleteBackward(nil)
        check(!doc.string.hasSuffix("\n") && blocks2().count == 1, "deleting last card: \(doc.string.debugDescription) \(blocks2())")
        spin()

        // Code fences restyle the lines after them
        doc.setSelectedRange(NSRange(location: 0, length: (doc.string as NSString).length))
        doc.insertText("one\ntwo", replacementRange: NSRange(location: NSNotFound, length: 0))
        spin()
        doc.setSelectedRange(NSRange(location: 0, length: 0))
        doc.insertText("```\n", replacementRange: NSRange(location: NSNotFound, length: 0))
        spin()
        let codeFont = doc.textStorage?.attribute(.font, at: (doc.string as NSString).length - 1, effectiveRange: nil) as? NSFont
        check(codeFont?.isFixedPitch == true, "fence restyles later lines: \(String(describing: codeFont))")
        check(doc.selectedRange() == NSRange(location: 4, length: 0), "caret after fence: \(doc.selectedRange())")

        // Typing mid-paragraph keeps the caret where it is through styling
        doc.setSelectedRange(NSRange(location: 0, length: (doc.string as NSString).length))
        doc.insertText("- first item\n- second", replacementRange: NSRange(location: NSNotFound, length: 0))
        spin()
        doc.setSelectedRange(NSRange(location: 4, length: 0))
        doc.insertText("x", replacementRange: NSRange(location: NSNotFound, length: 0))
        spin()
        check(doc.selectedRange() == NSRange(location: 5, length: 0) && doc.string == "- fixrst item\n- second", "mid-paragraph caret: \(doc.selectedRange()) \(doc.string.debugDescription)")
        doc.undoManager?.undo(); spin()
        check(doc.string == "- first item\n- second", "undo after styling: \(doc.string.debugDescription)")

        // SwiftUI sizing follows content
        let sized = Reference()
        var sizedMaterial = Material(); sizedMaterial.insert(.text(UUID(), "line"), at: 0)
        Store.materials[sized] = sizedMaterial
        let host = NSHostingView(rootView: VStack(spacing: 0) { EditorView(sized, sizing: .fitsContent, autofocus: true); Spacer(minLength: 0) }.frame(width: 400, height: 800, alignment: .top))
        host.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        window.contentView = host
        host.layoutSubtreeIfNeeded(); spin(); host.layoutSubtreeIfNeeded()
        let hosted = host.subviews.first { $0 is EditorScrollView } as? EditorScrollView ?? { () -> EditorScrollView? in
            var stack: [NSView] = [host]; while let view = stack.popLast() { if let found = view as? EditorScrollView { return found }; stack += view.subviews }; return nil }()
        let before = hosted?.frame.height ?? 0
        hosted?.editor.setSelectedRange(NSRange(location: 4, length: 0))
        for _ in 0..<5 { hosted?.editor.insertText("\nmore", replacementRange: NSRange(location: NSNotFound, length: 0)) }
        spin(); host.layoutSubtreeIfNeeded(); spin(); host.layoutSubtreeIfNeeded()
        let after = hosted?.frame.height ?? 0
        check(hosted != nil && before > 0 && after > before * 3, "hosted editor grows with content: \(before) -> \(after)")
        check(window.firstResponder === hosted?.editor, "autofocus makes editor first responder")

        // A task that wraps gets a card as tall as its wrapped text
        let wrapping = Reference(), long = UUID()
        let longTask = Material.Block.task(long, String(repeating: "wrapping task text ", count: 20), false)
        var wrappingMaterial = Material()
        wrappingMaterial.insert([.text(UUID(), "Intro"), longTask], at: 0)
        Store.materials[wrapping] = wrappingMaterial
        let wrapped = ScintEditor(wrapping, autofocus: false)
        let wrappedScroll = EditorScrollView(wrapped, sizing: .fitsContent)
        window.contentView = wrappedScroll
        wrappedScroll.frame = CGRect(x: 0, y: 0, width: 480, height: 600)
        spin(); wrapped.textLayout.textViewportLayoutController.layoutViewport(); window.displayIfNeeded(); spin()
        let taskFrame = wrapped.card(long)?.view?.frame.height ?? 0
        let needed = NSHostingController(rootView: MaterialBlock(block: longTask)).sizeThatFits(in: CGSize(width: wrapped.container.size.width, height: .greatestFiniteMagnitude)).height
        check(needed > 60 && abs(taskFrame - needed) < 1, "wrapped task card is as tall as its text: \(taskFrame) for \(needed) at \(wrapped.container.size.width)")

        print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
        exit(failures == 0 ? 0 : 1)
    }
}
