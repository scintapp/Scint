import AgencyRuntime
import AppKit
import SwiftUI

typealias Entry = Sheet.Entry


@Observable final class SheetModel {
    let ref: Reference
    var entries: [Entry] { didSet { dirty = true } }
    private(set) var dirty = false

    init(ref: Reference) {
        self.ref = ref
        let existing = Sheet.with(ref, { $0.entries }) ?? []
        self.entries = existing.isEmpty ? [.text(UUID(), "")] : existing
    }

    func sync() {
        Sheet.update(ref) { $0.entries = entries }
        dirty = false
    }
}


@Observable final class EditorModel {
    let menu: MenuModel
    let sheet: SheetModel
    var segments: [EditorSegment]
    var focusedSegmentID: UUID?
    var caretRect: CGRect = .zero
    var segmentFrames: [UUID: CGRect] = [:]
    var documentFrame: CGRect = .zero
    var renderVersion = 0
    let makeEntries: (MenuItem) -> [Entry]?
    var activateExternalEntry: (Entry) -> Void


    init(sheet: SheetModel, menuItems: [MenuItem],
         makeEntries: @escaping (MenuItem) -> [Entry]?,
         activateExternalEntry: @escaping (Entry) -> Void = { _ in }) {

        self.sheet = sheet
        self.menu = MenuModel(items: menuItems)
        self.makeEntries = makeEntries
        self.activateExternalEntry = activateExternalEntry
        self.segments = EditorSegmentBuilder.build(from: sheet.entries)
        self.focusedSegmentID = self.segments.first?.id
        syncEntries(skipDirty: true)
    }

    func focusGained(segmentID: UUID) {
        focusedSegmentID = segmentID
    }

    func select(segmentID: UUID, selection: NSRange, caretRect: CGRect) {
        focusedSegmentID = segmentID
        self.caretRect = caretRect
        if let i = segments.firstIndex(where: { $0.id == segmentID }) {
            var s = segments[i]
            s.selection = selection
            segments[i] = s
        }
        updateMenu(allowOpen: false)
    }

    func write(segmentID: UUID, text: String, selection: NSRange, caretRect: CGRect) {
        focusedSegmentID = segmentID
        self.caretRect = caretRect
        guard let i = segments.firstIndex(where: { $0.id == segmentID }) else { return }
        var s = segments[i]
        s.text = text
        s.selection = selection
        s.attachments = EditorSegmentBuilder.filterAttachments(s.attachments, keepingTokensIn: text)
        segments[i] = s
        syncEntries()
        updateMenu(allowOpen: true)
    }

    func updateSegmentFrame(_ id: UUID, frame: CGRect) {
        if segmentFrames[id] != frame { segmentFrames[id] = frame }
    }

    var anchorRect: CGRect {
        guard let id = focusedSegmentID, let frame = segmentFrames[id] else { return caretRect }
        return CGRect(
            x: frame.minX + caretRect.minX,
            y: frame.minY + caretRect.minY,
            width: caretRect.width,
            height: caretRect.height
        )
    }

    var librarySections: [EditorLibrarySection] {
        EditorLibrarySearch.sections(for: menu.query)
    }

    var libraryItems: [EditorLibraryItem] {
        librarySections.flatMap(\.items)
    }

    func moveMenuSelection(_ delta: Int) {
        switch menu.kind {
        case .command:
            menu.cycle(reverse: delta < 0)
        case .library:
            let count = libraryItems.count
            guard count > 0 else { return }
            menu.libraryIndex = (menu.libraryIndex + delta + count) % count
        case .form:
            break
        }
    }

    func selectLibraryItem(_ item: EditorLibraryItem) {
        guard let index = libraryItems.firstIndex(of: item) else { return }
        menu.libraryIndex = index
    }

    func commitMenu() {
        switch menu.kind {
        case .command:
            commitCommandMenu()
        case .library:
            commitLibraryMenu()
        case .form(let formKind):
            commitFormMenu(formKind)
        }
    }

    private func commitCommandMenu() {
        guard let activation = menu.activateSelection() else {
            menu.close()
            return
        }
        switch activation {
        case .insert(let item, let replacementRange):
            if item.id == "new-task" {
                menu.openForm(.task)
                return
            }
            if item.id == "new-link" {
                menu.openForm(.link)
                return
            }
            guard let newEntries = makeEntries(item), !newEntries.isEmpty else {
                menu.close()
                return
            }
            insert(newEntries, replacing: replacementRange)
            menu.close()
        case .openSubmenu:
            break
        }
    }

    private func commitLibraryMenu() {
        let items = libraryItems
        guard items.indices.contains(menu.libraryIndex),
              let entry = EditorLibrarySearch.entry(for: items[menu.libraryIndex].ref) else {
            menu.close()
            return
        }
        insert([entry], replacing: menu.replacementRange)
        menu.close()
    }

    private func commitFormMenu(_ kind: ComponentFormKind) {
        let title = menu.formPrimary.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry: Entry

        switch kind {
        case .task:
            entry = .todo(UUID(), title.isEmpty ? "Task" : title, false)
        case .link:
            let fallbackTitle = title.isEmpty ? "Link" : title
            let url = normalizedURL(from: menu.formSecondary)
            let ref = Artifact.register(fallbackTitle, url)
            if url == nil { Artifact.update(ref) { $0.entry = .http(nil) } }
            entry = .artifact(ref)
        }

        insert([entry], replacing: menu.replacementRange)
        menu.close()
    }

    func componentEntry(for id: UUID) -> Entry? {
        for segment in segments {
            if let entry = segment.attachments[id] { return entry }
        }
        return nil
    }

    func registerInlineEntries(_ entries: [Entry]) {
        guard let i = focusedSegmentIndex else { return }
        var s = segments[i]
        for entry in entries {
            s.attachments[entry.id] = entry
        }
        segments[i] = s
    }

    func updateInlineEntry(_ entry: Entry) {
        for i in segments.indices where segments[i].attachments[entry.id] != nil {
            segments[i].attachments[entry.id] = entry
            renderVersion += 1
            syncEntries()
            return
        }
    }

    func activate(_ entry: Entry) {
        switch entry {
        case .todo: break
        case .artifact, .control, .service, .sheet: activateExternalEntry(entry)
        case .text: break
        }
    }

    private var focusedSegmentIndex: Int? {
        guard let id = focusedSegmentID else { return nil }
        return segments.firstIndex(where: { $0.id == id })
    }

    private func insert(_ newEntries: [Entry], replacing range: NSRange) {
        guard let i = focusedSegmentIndex else { return }
        var s = segments[i]
        let ns = s.text as NSString
        var replacement = ""
        for (idx, entry) in newEntries.enumerated() {
            if idx > 0 { replacement.append(" ") }
            switch entry {
            case .text(_, let value):
                replacement.append(value)
            case .artifact, .control, .service, .sheet, .todo:
                s.attachments[entry.id] = entry
                replacement.append(EditorAttachment.token(for: entry.id))
            }
        }
        s.text = ns.replacingCharacters(in: range, with: replacement)
        s.selection = NSRange(location: range.location + (replacement as NSString).length, length: 0)
        segments[i] = s
        renderVersion += 1
        syncEntries()
    }

    private func syncEntries(skipDirty: Bool = false) {
        let newEntries = EditorSegmentBuilder.entries(from: segments)
        if skipDirty {
            if sheet.entries != newEntries { sheet.entries = newEntries }
        } else {
            sheet.entries = newEntries
        }
    }

    private func updateMenu(allowOpen: Bool) {
        guard allowOpen || menu.isOpen else { return }
        guard let trigger = detectTrigger() else {
            if menu.isOpen { menu.close() }
            return
        }
        menu.open(kind: trigger.kind, query: trigger.query, replacementRange: trigger.range, anchorRect: anchorRect)
    }

    private func detectTrigger() -> (kind: EditorMenuKind, query: String, range: NSRange)? {
        guard let i = focusedSegmentIndex else { return nil }
        let s = segments[i]
        let ns = s.text as NSString
        let cursor = s.selection.location
        guard cursor > 0, cursor <= ns.length else { return nil }

        var index = cursor - 1
        while index >= 0 {
            let character = ns.substring(with: NSRange(location: index, length: 1))
            if character == "/" || character == "@" {
                guard isTriggerBoundary(before: index, in: s.text) else { return nil }
                let queryRange = NSRange(location: index + 1, length: cursor - index - 1)
                let query = ns.substring(with: queryRange)
                guard !query.contains(where: \.isWhitespace) else { return nil }
                return (
                    character == "/" ? .command : .library,
                    query,
                    NSRange(location: index, length: cursor - index)
                )
            }
            if character == " " || character == "\t" || character == "\n" { return nil }
            index -= 1
        }
        return nil
    }

    private func isTriggerBoundary(before index: Int, in text: String) -> Bool {
        guard index > 0 else { return true }

        let ns = text as NSString
        let previous = ns.substring(with: NSRange(location: index - 1, length: 1))
        if previous == " " || previous == "\t" || previous == "\n" { return true }

        return EditorAttachment.matches(in: text).contains { match in
            match.range.location + match.range.length == index
        }
    }

    private func normalizedURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil { return url }
        return URL(string: "https://\(trimmed)")
    }
}
