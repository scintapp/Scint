import AppKit


@MainActor final class FindClient: NSObject, @preconcurrency NSTextFinderClient {
    let editor: ScintEditor
    weak var host: EditorDocumentView?
    init(editor: ScintEditor, host: EditorDocumentView) { self.editor = editor; self.host = host }
    private var entries: [(id: AnyHashable, string: String, range: NSRange)] {
        var offset = 0
        return editor.blocks.compactMap { block in
            guard case .text(_, let text) = block else { return nil }
            defer { offset += text.utf16.count + 1 }
            return (block.id, text, NSRange(location: offset, length: text.utf16.count))
        }
    }
    var string: String { entries.map(\.string).joined(separator: "\n") }
    func string(at characterIndex: Int, effectiveRange outRange: NSRangePointer, endsWithSearchBoundary outFlag: UnsafeMutablePointer<ObjCBool>) -> String {
        for entry in entries {
            if NSLocationInRange(characterIndex, entry.range) {
                outRange.pointee = entry.range; outFlag.pointee = true; return entry.string
            }
            if characterIndex == NSMaxRange(entry.range) {
                outRange.pointee = NSRange(location: characterIndex, length: 1); outFlag.pointee = true; return "\n"
            }
        }
        outRange.pointee = NSRange(location: characterIndex, length: 0); outFlag.pointee = true; return ""
    }
    var stringLength: Int { string.utf16.count }
    var isEditable: Bool { true }
    var allowsMultipleSelection: Bool { false }
    var firstSelectedRange: NSRange { selectedRanges.first?.rangeValue ?? NSRange(location: 0, length: 0) }
    var selectedRanges: [NSValue] {
        get {
            if case .text(let id, let anchor, let head) = editor.position,
               let entry = entries.first(where: { $0.id == id }) {
                return [NSValue(range: NSRange(location: entry.range.location + min(anchor, head), length: abs(head - anchor)))]
            }
            let selected = Set(editor.selectedBlockIDs)
            return entries.filter { selected.contains($0.id) }.map { NSValue(range: $0.range) }
        }
        set {
            guard let range = newValue.first?.rangeValue, let entry = owner(range) else { return }
            editor.place(.text(id: entry.id, anchor: range.location - entry.range.location, head: NSMaxRange(range) - entry.range.location))
        }
    }
    private func owner(_ range: NSRange) -> (id: AnyHashable, string: String, range: NSRange)? {
        entries.first { range.location >= $0.range.location && NSMaxRange(range) <= NSMaxRange($0.range) }
    }
    func scrollRangeToVisible(_ range: NSRange) {
        guard let entry = owner(range) else { return }
        host?.textView(entry.id)?.scrollRangeToVisible(NSRange(location: range.location - entry.range.location, length: range.length))
    }
    func shouldReplaceCharacters(inRanges ranges: [NSValue], with strings: [String]) -> Bool {
        guard ranges.allSatisfy({ owner($0.rangeValue) != nil }) else { return false }
        editor.beginGroup(); return true
    }
    func replaceCharacters(in range: NSRange, with string: String) {
        guard let entry = owner(range) else { return }
        let start = range.location - entry.range.location
        editor.replace(in: entry.id, range: start..<(start + range.length), with: string)
    }
    func didReplaceCharacters() { editor.endGroup() }
    func contentView(at index: Int, effectiveCharacterRange outRange: NSRangePointer) -> NSView {
        guard let entry = entries.first(where: { NSLocationInRange(index, $0.range) || index == NSMaxRange($0.range) }),
              let view = host?.textView(entry.id) else { return host ?? NSView() }
        outRange.pointee = entry.range; return view
    }
    func rects(forCharacterRange range: NSRange) -> [NSValue]? {
        guard let entry = owner(range), let view = host?.textView(entry.id) else { return nil }
        return view.frames(for: NSRange(location: range.location - entry.range.location, length: range.length)).map { NSValue(rect: $0) }
    }
    var visibleCharacterRanges: [NSValue] {
        entries.compactMap { entry in
            guard let view = host?.textView(entry.id), !view.visibleRect.isEmpty else { return nil }
            let lower = view.characterIndexForInsertion(at: view.visibleRect.origin)
            let upper = view.characterIndexForInsertion(at: CGPoint(x: view.visibleRect.maxX, y: view.visibleRect.maxY))
            return NSValue(range: NSRange(location: entry.range.location + min(lower, upper), length: abs(upper - lower)))
        }
    }
}
