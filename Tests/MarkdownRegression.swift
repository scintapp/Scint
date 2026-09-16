import AppKit
import SwiftUI

// The harness compiles the production Markdown parser and renderer in isolation.
// Only application routing and the asset-catalog accent are substituted; no window is opened.
extension Color { static var accent: Color { .accentColor } }
enum CallbackRouter { static func open(_ ref: Reference) {} }
struct Card: View {
    enum Style { case group }
    var ref: Reference
    var style: Style
    var isSelected: Bool = false
    var body: some View { EmptyView() }
}
struct Chip: View {
    let ref: Reference
    var label: String? = nil
    var body: some View { EmptyView() }
}
enum Iconography {
    struct Icon: View {
        var symbol: String
        var tint: Color
        var sizing: CGFloat
        var body: some View { Image(systemName: symbol).foregroundStyle(tint) }
    }
}

@main enum MarkdownRegression {
    @MainActor static func main() throws {
        if ProcessInfo.processInfo.environment["SCINT_EDITOR_PERF"] == "1" { EditorPerformance.run(); return }
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }
        let table = """
        | Method | Meaning | Count |
        | :--- | :---: | ---: |
        | `a|b` | escaped \\| pipe | 3 |
        | `write` | **bold** | 5 |
        """
        guard case .table(let rows, let alignment)? = Markdown.elements(table).first else { fatalError("Table was not parsed") }
        check(rows.count == 3 && rows[0].count == 3, "Header and body rows")
        check(rows[1][0] == "`a|b`" && rows[1][1] == "escaped | pipe", "Pipes inside code and escaped pipes")
        check(alignment == [.leading, .center, .trailing], "Column alignment")
        check(Markdown.elements("a | b\n--- | --\nc | d").count == 1, "Invalid delimiter remains prose")
        guard case .table(let ragged, _)? = Markdown.elements("a | b\n--- | ---\nx |\ny | z | extra").first else { fatalError("Ragged table") }
        check(ragged[1] == ["x", ""] && ragged[2] == ["y", "z"], "Missing cells padded and excess cells omitted")
        let fence = "  ````swift\nlet a = \"```\"\n```\n  ````\nAfter"
        guard case .code(let code, let language)? = Markdown.elements(fence).first else { fatalError("Fence was not parsed") }
        check(language == "swift" && code == "let a = \"```\"\n```", "Only a matching fence closes code")
        guard case .code(let pending, _)? = Markdown.elements("~~~\nunfinished").first else { fatalError("Unclosed fence") }
        check(pending == "unfinished", "Streaming unfinished fence")
        check(Markdown.elements("- one\n  * two\n+ three").count == 3, "Bullet variants")
        guard case .quote(let quote)? = Markdown.elements("> first\n> second").first else { fatalError("Quote") }
        check(quote == "first\nsecond", "Quote markers removed")
        let link = "[Apple](https://example.com/a_(b))"
        let parsed = Markdown.scan(link)
        check(parsed.links.count == 1, "Balanced link")
        check((link as NSString).substring(with: parsed.links[0].url) == "https://example.com/a_(b)", "Full destination")
        check(Markdown.scan("`[not a link](https://example.com)`").links.isEmpty, "Code protects link syntax")
        let literal = Markdown.scan("``**literal** ` tick``")
        check(!literal.spans.contains(where: { $0.kind == .strong }), "Code protects emphasis syntax")
        let displayed = Attribute.markdown("Hello **world** and `code` — " + link, font: Typography.Prose.appKitText, reasoning: false, alignment: .left)
        check(!displayed.string.contains("**") && !displayed.string.contains("`"), "Display delimiters removed")
        check(!displayed.string.contains("https://"), "Link destination hidden")
        let label = (displayed.string as NSString).range(of: "Apple")
        check(displayed.attribute(.link, at: label.location, effectiveRange: nil) as? URL == URL(string: "https://example.com/a_(b)"), "Link remains actionable")
        let codeLocation = (displayed.string as NSString).range(of: "code").location
        check(displayed.attribute(.markdownCode, at: codeLocation, effectiveRange: nil) != nil, "Code decoration retained")
        check(displayed.string.contains("\u{00a0}code\u{00a0}"), "Code has horizontal padding")
        let unicode = Attribute.markdown("👩🏽‍💻 **café** [日本語](https://example.com)", font: Typography.Prose.appKitText, reasoning: false, alignment: .left)
        check(unicode.string == "👩🏽‍💻 café 日本語", "UTF-16 ranges preserve Unicode")
        let editorSource = "- bullet\n> quote\n```swift\nlet x = 1\n```\n[Link](https://example.com) and `code`"
        let themed = NSMutableAttributedString(string: editorSource)
        Styler().apply(to: themed, document: Markdown.scan(editorSource), scope: [NSRange(location: 0, length: themed.length)])
        check(themed.string == editorSource, "Editor styling preserves source characters and offsets")
        let codeBody = (editorSource as NSString).range(of: "let x").location
        check(themed.attribute(.foregroundColor, at: codeBody, effectiveRange: nil) as? NSColor == NSColor(Style.Foreground.primary), "Editor code remains readable")
        let fenceLocation = (editorSource as NSString).range(of: "```").location
        check((themed.attribute(.font, at: fenceLocation, effectiveRange: nil) as? NSFont)?.pointSize == Typography.Scale.hiddenSyntax, "Editor fences use hidden syntax font")
        check(Markdown.scan(editorSource).links.count == 1, "Editor resolves links from source ranges")
        let editorInline = (editorSource as NSString).range(of: "`code`").location
        check(themed.attribute(.kern, at: editorInline, effectiveRange: nil) as? CGFloat == Style.Spacing.sm, "Editor code delimiters reserve padding")
        let titled = Attribute.markdown("[site](<https://example.com/a_(b)> \"Title\")", font: Typography.Prose.appKitText, reasoning: false, alignment: .left)
        check(titled.string == "site", "Link titles and angle delimiters are hidden")
        check(titled.attribute(.link, at: 0, effectiveRange: nil) as? URL == URL(string: "https://example.com/a_(b)"), "Link titles are excluded from destinations")
        let view = MarkdownTextView()
        view.render(String(repeating: "A line with `code` and a [link](https://example.com). ", count: 6), font: Typography.Prose.appKitText, reasoning: false, alignment: .left)
        let wide = view.measure(640)
        let narrow = view.measure(240)
        check(wide.height > 0 && narrow.height > wide.height, "Text reflows at narrow widths")
        let mixedBold = "**Documents and content — `scint.content`**"
        let mixed = Attribute.markdown(mixedBold, font: Typography.Prose.appKitText, reasoning: false, alignment: .left)
        check(!mixed.string.contains("**"), "Bold delimiters enclosing inline code are removed")
        let mixedFont = mixed.attribute(.font, at: 0, effectiveRange: nil) as! NSFont
        check(NSFontManager.shared.traits(of: mixedFont).contains(.boldFontMask), "Text enclosing inline code stays bold")
        let editorMixed = NSMutableAttributedString(string: mixedBold)
        Styler().apply(to: editorMixed, document: Markdown.scan(mixedBold), scope: [NSRange(location: 0, length: editorMixed.length)])
        check((editorMixed.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize == Typography.Scale.hiddenSyntax, "Editor hides enclosing bold delimiters too")
        view.frame = CGRect(origin: .zero, size: wide)
        _ = view.measure(18)
        check(abs((view.textContainer?.containerSize.width ?? 0) - wide.width) < 1, "Speculative measurement cannot change the live container width")

        let editorTableSource = "Before 👩🏽‍💻\n\n" + table + "\n\nAfter"
        let blockID = UUID(), ref = Reference()
        Material.store[ref] = Material(blocks: [.text(blockID, editorTableSource)])
        let model = Editor(material: ref)
        let container = EditorDocumentView(editor: model, sizing: .fitsContent, autofocus: false, onFocus: {}, onReturn: nil, onEditCard: { _, _ in })
        let editor = EditorTextView(editor: model, id: blockID, host: container)
        container.addSubview(editor)
        editor.frame = CGRect(x: 0, y: 0, width: 640, height: 1000)
        model.attach(editor, to: blockID)
        check(editor.storage.string == editorTableSource, "Table presentation preserves every source character")
        check(editor.textLayoutManager != nil, "Editor uses TextKit 2")
        var hasAttachment = false
        editor.storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: editor.storage.length)) { value, _, _ in
            if value != nil { hasAttachment = true }
        }
        check(!hasAttachment, "No text attachments")
        let identity = ObjectIdentifier(editor)
        model.type("\n")
        check(ObjectIdentifier(editor) == identity && editor.storage.string == model.string(blockID), "Newline preserves view identity and source equality")
        model.undo(); check(editor.storage.string == editorTableSource, "Undo patches storage synchronously")
        model.place(.text(id: blockID, anchor: 0, head: 0))
        let accepted = editor.textView(editor, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementString: "Pasted\r\n")
        check(!accepted && editor.storage.string == model.string(blockID), "Paste routes through editor and normalizes newlines")
        model.undo()
        editor.setMarkedText("仮", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: 0, length: 0))
        check(model.string(blockID) == editorTableSource, "IME composition is transient")
        editor.insertText("日本語", replacementRange: NSRange(location: NSNotFound, length: 0))
        check(editor.storage.string == model.string(blockID) && editor.storage.string.hasPrefix("日本語"), "IME commit synchronizes material and storage")
        model.undo(); check(editor.storage.string == editorTableSource, "IME undo restores original source")
        let finder = FindClient(editor: model, host: container)
        check(finder.shouldReplaceCharacters(inRanges: [NSValue(range: NSRange(location: 0, length: 6))], with: ["Changed"]), "Find opens a replacement group")
        finder.replaceCharacters(in: NSRange(location: 0, length: 6), with: "Changed")
        finder.didReplaceCharacters()
        check(editor.storage.string == model.string(blockID), "Find replacement patches storage synchronously")
        model.undo(); check(editor.storage.string == editorTableSource, "Find undo restores original source")
        let hostedRef = Reference(), hostedID = UUID()
        Material.store[hostedRef] = Material(blocks: [.text(hostedID, "Hosted")])
        let hostedEditor = Editor(material: hostedRef)
        let documentHost = EditorDocumentView(editor: hostedEditor, sizing: .fitsContent, autofocus: true, onFocus: {}, onReturn: nil, onEditCard: { _, _ in })
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 640, height: 500), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = documentHost
        documentHost.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        documentHost.layoutSubtreeIfNeeded()
        guard let hostedText = documentHost.textView(hostedID) else { fatalError("SwiftUI did not mount its text block") }
        check(window.firstResponder === hostedText, "Autofocus follows initial position without retries")
        let undoItem = NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        let findItem = NSMenuItem(title: "Find", action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "f")
        findItem.tag = NSTextFinder.Action.showFindInterface.rawValue
        check(!hostedText.validateMenuItem(undoItem), "Undo menu is disabled before an edit")
        hostedEditor.type("X")
        let editedHostedSource = hostedText.storage.string
        check(hostedText.validateMenuItem(undoItem), "Undo menu enables for editor-owned history despite allowsUndo=false")
        check(NSApp.sendAction(undoItem.action!, to: hostedText, from: undoItem), "Undo selector reaches the text responder")
        check(hostedText.storage.string == "Hosted", "Menu Undo restores source")
        check(hostedText.validateMenuItem(redoItem), "Redo menu enables after Undo")
        check(NSApp.sendAction(redoItem.action!, to: hostedText, from: redoItem), "Redo selector reaches the text responder")
        check(hostedText.storage.string == editedHostedSource, "Menu Redo restores the edit")
        func shortcut(_ key: String, shift: Bool = false) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: shift ? [.command, .shift] : .command,
                             timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: key,
                             charactersIgnoringModifiers: key, isARepeat: false, keyCode: 0)!
        }
        check(hostedText.performKeyEquivalent(with: shortcut("z")), "Command-Z is handled")
        check(hostedText.storage.string == "Hosted", "Command-Z undoes the edit")
        check(hostedText.performKeyEquivalent(with: shortcut("z", shift: true)), "Shift-Command-Z is handled")
        check(hostedText.storage.string == editedHostedSource, "Shift-Command-Z redoes the edit")
        check(hostedText.validateMenuItem(findItem), "Find menu validates against the shared finder")
        window.makeKeyAndOrderFront(nil)
        fputs("FIND BEFORE focus=\(String(describing: window.firstResponder)) owns=\(documentHost.ownsFocus) container=\(String(describing: documentHost.finder.findBarContainer))\n", stderr)
        check(hostedText.performKeyEquivalent(with: shortcut("f")), "Command-F is handled")
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        documentHost.layoutSubtreeIfNeeded()
        fputs("FIND AFTER visible=\(documentHost.isFindBarVisible) bar=\(String(describing: documentHost.findBarView)) focus=\(String(describing: window.firstResponder))\n", stderr)
        check(documentHost.isFindBarVisible && documentHost.findBarView != nil, "Command-F opens the actual find bar")
        guard let searchField = documentHost.descendants(NSSearchField.self).first else { fatalError("Find bar has no search field") }
        window.makeFirstResponder(searchField)
        let searchResponder = window.firstResponder
        documentHost.refresh()
        check(window.firstResponder === searchResponder, "Refreshing does not steal focus from Find")
        documentHost.findClient.selectedRanges = [NSValue(range: NSRange(location: 1, length: 4))]
        check(window.firstResponder === searchResponder, "Selecting a find result retains search-field focus")
        check(!Keymap.performKeyEquivalent(shortcut("z"), host: documentHost), "Document shortcuts do not intercept the find field's Undo")
        documentHost.performFindAction(.hideFindInterface)
        window.makeFirstResponder(hostedText)
        hostedEditor.undo()
        let hostedIdentity = ObjectIdentifier(hostedText)
        documentHost.focusPosition()
        hostedEditor.type("\n")
        documentHost.refresh()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        documentHost.layoutSubtreeIfNeeded()
        check(documentHost.textView(hostedID).map(ObjectIdentifier.init) == hostedIdentity, "SwiftUI ForEach preserves NSTextView identity across newline")
        check(hostedText.storage.string == hostedEditor.string(hostedID), "Hosted text stays synchronized")
        let hostedCard = Material.Block.task(UUID(), "Task", false)
        hostedEditor.insertCard(hostedCard)
        documentHost.refresh()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        documentHost.layoutSubtreeIfNeeded()
        check((window.firstResponder as? EditorCardView)?.block.id == hostedCard.id, "Focus follows insertion into a new card")
        if let cardView = documentHost.descendants(EditorCardView.self).first {
            check(cardView.hitTest(CGPoint(x: cardView.frame.midX, y: cardView.frame.midY)) === cardView, "Card hit testing uses its placed coordinates")
        }
        window.contentView = nil
        let fixture = """
        # Markdown rendering

        **Documents and content — `scint.content`**

        A paragraph with **strong text**, *emphasis*, `inline code`, and a [working link](https://example.com/a_(b)).

        - A disc replaces the dash.
        - Another item with `code` that wraps naturally when the view is narrow.

        > A quote uses a left bar, with no visible greater-than marker.
        > Its next line remains inside the quote.

        ```swift
        let message = "Readable code"
        print(message)
        ```

        \(table)
        """
        let controller = NSHostingController(rootView: TextBlock(content: fixture))
        let blockSize = controller.sizeThatFits(in: CGSize(width: 640, height: CGFloat.greatestFiniteMagnitude))
        check(blockSize.height.isFinite && blockSize.height > 100 && blockSize.height < 2000, "Markdown block/table layout has finite intrinsic height")
        let narrowBlockSize = controller.sizeThatFits(in: CGSize(width: 280, height: CGFloat.greatestFiniteMagnitude))
        check(narrowBlockSize.height.isFinite && narrowBlockSize.width <= 280, "Wide tables stay inside a horizontally scrollable viewport")
        let limited = NSHostingController(rootView: TextBlock(content: fixture).lineLimit(5))
        let limitedSize = limited.sizeThatFits(in: CGSize(width: 640, height: CGFloat.greatestFiniteMagnitude))
        check(limitedSize.height <= 5 * (Typography.Prose.appKitLineHeight + Style.Spacing.sm) + Style.Spacing.markdownTextInset * 2, "Activity preview retains its five-line height limit")
        if let renderPath = ProcessInfo.processInfo.environment["SCINT_MARKDOWN_RENDER"] {
            let host = NSHostingView(rootView: TextBlock(content: fixture).padding(Style.Spacing.xxl).background(Style.Background.base).environment(\.colorScheme, .dark))
            host.frame = CGRect(x: 0, y: 0, width: 688, height: blockSize.height + Style.Spacing.xxl * 2)
            host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("Bitmap unavailable") }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: renderPath))

            func save(_ view: NSView, to suffix: String) throws {
                view.layoutSubtreeIfNeeded()
                guard let image = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("Bitmap unavailable") }
                view.cacheDisplay(in: view.bounds, to: image)
                try image.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: renderPath + suffix))
            }
            func paragraphs(in view: NSView) -> [MarkdownTextView] {
                (view as? MarkdownTextView).map { [$0] } ?? view.subviews.flatMap { paragraphs(in: $0) }
            }
            let activitySource = """
            Called `scint.content.list` successfully.

            - **Context — Editorial System**: `scint://transcript/1234567890abcdef` contains the latest response.
            - More information follows in another paragraph with `inline code` and a [link](https://example.com).
            """
            let activityContent = VStack(alignment: .leading, spacing: Style.Spacing.xxl) {
                Text("Last Turn").font(Typography.prose)
                Divider()
                TextBlock(content: activitySource).lineLimit(5)
                Divider()
                Text("scint.content.list                         Completed").font(Typography.proseCode)
            }
            .padding(Style.Spacing.xl)
            .background(Style.Background.card)
            let activityHost = NSHostingView(rootView: Button {} label: { activityContent.allowsHitTesting(false) }.buttonStyle(.plain).environment(\.colorScheme, .dark))
            let activityMeasure = NSHostingController(rootView: activityContent)
            activityHost.frame = CGRect(origin: .zero, size: activityMeasure.sizeThatFits(in: CGSize(width: 640, height: CGFloat.greatestFiniteMagnitude)))
            try save(activityHost, to: ".activity.png")
            for paragraph in paragraphs(in: activityHost) {
                check(abs((paragraph.textContainer?.containerSize.width ?? 0) - paragraph.bounds.width) < 1, "Activity paragraphs use their placed width")
                check(paragraph.measure(paragraph.bounds.width).height <= paragraph.bounds.height + 1, "Activity paragraphs are not vertically compressed")
            }

            editor.textLayoutManager?.textViewportLayoutController.layoutViewport()
            editor.frame.size = CGSize(width: 640, height: editor.contentHeight)
            try save(editor, to: ".editor.png")
            let longTable = "| Method | Description | Arguments |\n| --- | --- | --- |\n" + (0..<8).map { row in
                "| `method_\(row)` | A longer description of the method that wraps across several lines in a narrow table column. | `name`; optional `description`, `tags` |"
            }.joined(separator: "\n") + "\n| LAST_ROW | This final row must remain fully visible with all of its padding. | `done` |"
            let longController = NSHostingController(rootView: TextBlock(content: longTable))
            let longSize = longController.sizeThatFits(in: CGSize(width: 640, height: CGFloat.greatestFiniteMagnitude))
            let longHost = NSHostingView(rootView: TextBlock(content: longTable).background(Style.Background.base).environment(\.colorScheme, .dark))
            longHost.frame = CGRect(origin: .zero, size: longSize)
            try save(longHost, to: ".table.png")
            for paragraph in paragraphs(in: longHost) {
                check(paragraph.measure(paragraph.bounds.width).height <= paragraph.bounds.height + 1, "Table cells fit their allocated row height")
                if paragraph.string == "LAST_ROW" {
                    check(longHost.bounds.contains(paragraph.convert(paragraph.bounds, to: longHost)), "Last table row fits inside the table viewport")
                }
            }
        }
        print("Passed \(checks) Markdown parsing, attributed-text, and layout checks")
        EditorPerformance.run()
    }
}
