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
        self.focusedSegmentID = self.segments.first(where: { $0.isText })?.id
        syncEntries(skipDirty: true)
    }

    var isTextFocused: Bool { focusedSegmentID != nil }

    func focusGained(segmentID: UUID) {
        focusedSegmentID = segmentID
    }

    func select(segmentID: UUID, selection: NSRange, caretRect: CGRect) {
        focusedSegmentID = segmentID
        self.caretRect = caretRect
        if let i = segments.firstIndex(where: { $0.id == segmentID }),
           case .text(var s) = segments[i] {
            s.selection = selection
            segments[i] = .text(s)
        }
        updateMenu(allowOpen: false)
    }

    func write(segmentID: UUID, text: String, selection: NSRange, caretRect: CGRect) {
        focusedSegmentID = segmentID
        self.caretRect = caretRect
        guard let i = segments.firstIndex(where: { $0.id == segmentID }),
              case .text(var s) = segments[i] else { return }
        s.text = text
        s.selection = selection
        s.attachments = EditorSegmentBuilder.filterAttachments(s.attachments, keepingTokensIn: text)
        segments[i] = .text(s)
        syncEntries()
        updateMenu(allowOpen: true)
    }

    func updateTask(segmentID: UUID, title: String? = nil, complete: Bool? = nil) {
        guard let i = segments.firstIndex(where: { $0.id == segmentID }),
              case .task(var t) = segments[i] else { return }
        if let title { t.title = title }
        if let complete { t.complete = complete }
        segments[i] = .task(t)
        syncEntries()
    }

    func focusTask(segmentID: UUID) {
        focusedSegmentID = segmentID
    }

    func taskReturn(from segmentID: UUID) {
        guard let i = segments.firstIndex(where: { $0.id == segmentID }) else { return }
        let nextIndex = i + 1
        if nextIndex < segments.count, segments[nextIndex].isText {
            focusedSegmentID = segments[nextIndex].id
            renderVersion += 1
            return
        }
        let new = EditorSegment.TextSegment(id: UUID(), text: "", attachments: [:], selection: NSRange(location: 0, length: 0))
        segments.insert(.text(new), at: nextIndex)
        focusedSegmentID = new.id
        syncEntries()
        renderVersion += 1
    }

    func taskDeleteBackward(segmentID: UUID) -> Bool {
        guard let i = segments.firstIndex(where: { $0.id == segmentID }),
              case .task(let t) = segments[i], t.title.isEmpty else { return false }
        var targetFocus: UUID?
        var targetCaret: Int = 0
        if i > 0, case .text(let prev) = segments[i - 1] {
            targetFocus = prev.id
            targetCaret = (prev.text as NSString).length
        }
        segments.remove(at: i)
        coalesceAdjacentText(around: i)
        if let targetFocus,
           let pi = segments.firstIndex(where: { $0.id == targetFocus }),
           case .text(var prev) = segments[pi] {
            prev.selection = NSRange(location: targetCaret, length: 0)
            segments[pi] = .text(prev)
            focusedSegmentID = prev.id
        } else if let first = segments.first(where: { $0.isText }) {
            focusedSegmentID = first.id
        }
        syncEntries()
        renderVersion += 1
        return true
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

    func commitMenu() {
        guard let activation = menu.activateSelection() else {
            menu.close()
            return
        }
        switch activation {
        case .insert(let item, let replacementRange):
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

    func componentEntry(for id: UUID) -> Entry? {
        for seg in segments {
            if case .text(let s) = seg, let entry = s.attachments[id] { return entry }
        }
        return nil
    }

    func registerInlineEntries(_ entries: [Entry]) {
        guard let i = focusedSegmentIndex,
              case .text(var s) = segments[i] else { return }
        for entry in entries {
            switch entry {
            case .todo: continue
            default: s.attachments[entry.id] = entry
            }
        }
        segments[i] = .text(s)
    }

    func activate(_ entry: Entry) {
        switch entry {
        case .todo: break
        case .artifact, .control, .sheet: activateExternalEntry(entry)
        case .text: break
        }
    }

    private var focusedSegmentIndex: Int? {
        guard let id = focusedSegmentID else { return nil }
        return segments.firstIndex(where: { $0.id == id })
    }

    private func insert(_ newEntries: [Entry], replacing range: NSRange) {
        guard let i = focusedSegmentIndex,
              case .text(var s) = segments[i] else { return }

        let hasTask = newEntries.contains { if case .todo = $0 { return true }; return false }

        if !hasTask {
            let ns = s.text as NSString
            var replacement = ""
            for (idx, entry) in newEntries.enumerated() {
                s.attachments[entry.id] = entry
                if idx > 0 { replacement.append(" ") }
                replacement.append(EditorAttachment.token(for: entry.id))
            }
            s.text = ns.replacingCharacters(in: range, with: replacement)
            s.selection = NSRange(location: range.location + (replacement as NSString).length, length: 0)
            segments[i] = .text(s)
            renderVersion += 1
            syncEntries()
            return
        }

        let ns = s.text as NSString
        let beforeText = ns.substring(with: NSRange(location: 0, length: range.location))
        let afterStart = range.location + range.length
        let afterText = ns.substring(with: NSRange(location: afterStart, length: ns.length - afterStart))

        let allAttachments = s.attachments
        let beforeAttachments = EditorSegmentBuilder.filterAttachments(allAttachments, keepingTokensIn: beforeText)
        let afterAttachments = EditorSegmentBuilder.filterAttachments(allAttachments, keepingTokensIn: afterText)

        s.text = beforeText
        s.attachments = beforeAttachments
        s.selection = NSRange(location: (beforeText as NSString).length, length: 0)

        var inserted: [EditorSegment] = [.text(s)]
        var firstTaskID: UUID?

        for entry in newEntries {
            switch entry {
            case .todo(let id, let title, let done):
                inserted.append(.task(.init(id: id, title: title, complete: done)))
                if firstTaskID == nil { firstTaskID = id }
            default: break
            }
        }

        let trailing = EditorSegment.TextSegment(
            id: UUID(),
            text: afterText,
            attachments: afterAttachments,
            selection: NSRange(location: 0, length: 0)
        )
        inserted.append(.text(trailing))

        segments.replaceSubrange(i...i, with: inserted)
        if let firstTaskID { focusedSegmentID = firstTaskID }
        renderVersion += 1
        syncEntries()
    }

    private func coalesceAdjacentText(around index: Int) {
        var i = max(0, index - 1)
        while i + 1 < segments.count {
            if case .text(var a) = segments[i], case .text(let b) = segments[i + 1] {
                let mergedText = a.text + b.text
                var merged = a.attachments
                for (k, v) in b.attachments { merged[k] = v }
                a.text = mergedText
                a.attachments = merged
                segments[i] = .text(a)
                segments.remove(at: i + 1)
            } else {
                i += 1
            }
        }
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
        menu.open(query: trigger.query, replacementRange: trigger.range, anchorRect: anchorRect)
    }

    private func detectTrigger() -> (query: String, range: NSRange)? {
        guard let i = focusedSegmentIndex,
              case .text(let s) = segments[i] else { return nil }
        let ns = s.text as NSString
        let cursor = s.selection.location
        guard cursor > 0, cursor <= ns.length else { return nil }

        var index = cursor - 1
        while index >= 0 {
            let character = ns.substring(with: NSRange(location: index, length: 1))
            if character == "/" || character == "@" {
                let atStart = index == 0
                let previousIsSpace: Bool = {
                    guard index > 0 else { return false }
                    let previous = ns.substring(with: NSRange(location: index - 1, length: 1))
                    return previous == " " || previous == "\t" || previous == "\n"
                }()
                guard atStart || previousIsSpace else { return nil }
                let queryRange = NSRange(location: index + 1, length: cursor - index - 1)
                let query = ns.substring(with: queryRange)
                guard !query.contains(where: \.isWhitespace) else { return nil }
                return (query, NSRange(location: index, length: cursor - index))
            }
            if character == " " || character == "\t" || character == "\n" { return nil }
            index -= 1
        }
        return nil
    }
}
