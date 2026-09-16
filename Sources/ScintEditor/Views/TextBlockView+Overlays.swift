import AppKit
import SwiftUI

struct OverlayKey: Hashable { let offset: Int; let source: String }
final class EditorOverlayView: NSHostingView<AnyView> {
    weak var owner: ScintEditorView?
    let sourceRange: NSRange
    let link: ScintEditor.Link?
    init(owner: ScintEditorView, range: NSRange, link: ScintEditor.Link?, root: AnyView) {
        self.owner = owner; self.sourceRange = range; self.link = link
        super.init(rootView: root)
    }
    required init(rootView: AnyView) { fatalError("Use init(owner:range:link:root:)") }
    required init?(coder: NSCoder) { fatalError("Use init(owner:range:link:root:)") }
    override func hitTest(_ point: NSPoint) -> NSView? { super.hitTest(point) == nil ? nil : self }
    override func mouseDown(with event: NSEvent) {
        guard let owner else { return }
        if event.modifierFlags.contains(.command), let link { owner.editor.open(link); return }
        if link != nil { owner.editor.place(.text(id: owner.id, anchor: sourceRange.location, head: NSMaxRange(sourceRange))) }
        else { owner.editor.place(.text(id: owner.id, anchor: sourceRange.location, head: sourceRange.location)) }
        window?.makeFirstResponder(owner)
    }
}
extension ScintEditorView {
    func styleOverlays() {
        let source = storage.string as NSString
        var active = Set<OverlayKey>()
        func install(_ range: NSRange, link: ScintEditor.Link?, root: AnyView) {
            let key = OverlayKey(offset: range.location, source: source.substring(with: range))
            active.insert(key)
            let overlay: EditorOverlayView
            if let existing = overlays[key] { overlay = existing; overlay.rootView = root }
            else {
                overlay = EditorOverlayView(owner: self, range: range, link: link, root: root)
                overlays[key] = overlay; addSubview(overlay)
            }
            let width = max(1, container.size.width)
            overlay.frame.size.width = width
            let height = max(1, overlay.fittingSize.height)
            storage.addAttributes([.font: Typography.Prose.appKitSyntaxHidden, .foregroundColor: NSColor.clear], range: range)
            let lines = document.blocks.filter { NSIntersectionRange($0.range, range).length > 0 }
            for (index, line) in lines.enumerated() {
                let paragraph = Typography.Prose.paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
                if index == 0 { paragraph.minimumLineHeight = height }
                else { paragraph.maximumLineHeight = Typography.Scale.hiddenSyntax; paragraph.paragraphSpacing = 0 }
                storage.addAttribute(.paragraphStyle, value: paragraph, range: NSIntersectionRange(line.range, range))
            }
        }
        for link in document.links {
            guard let reference = Reference.Link.reference(in: source.substring(with: link.url)),
                  source.substring(with: source.lineRange(for: link.range)).trimmingCharacters(in: .whitespacesAndNewlines) == source.substring(with: link.range) else { continue }
            let selected: Bool
            if case .text(id, let anchor, let head) = editor.position {
                selected = min(anchor, head) == link.range.location && max(anchor, head) == NSMaxRange(link.range)
            } else { selected = false }
            install(link.range, link: .reference(reference), root: AnyView(Card(ref: reference, style: .group, isSelected: selected)))
        }
        for table in tables {
            install(table, link: nil, root: AnyView(TextBlock(content: source.substring(with: table))))
        }
        for key in Set(overlays.keys).subtracting(active) { overlays.removeValue(forKey: key)?.removeFromSuperview() }
    }
    func layoutOverlays() {
        guard !overlays.isEmpty else { return }
        textLayout.enumerateTextLayoutFragments(from: textLayout.documentRange.location, options: [.ensuresLayout]) { fragment in
            let range = self.sourceRange(fragment.rangeInElement)
            for (key, overlay) in self.overlays where NSLocationInRange(key.offset, range) || key.offset == range.location {
                overlay.frame = CGRect(x: self.textContainerOrigin.x, y: fragment.layoutFragmentFrame.minY + self.textContainerOrigin.y,
                                       width: self.container.size.width, height: overlay.fittingSize.height)
            }
            return true
        }
    }
}
