
import Foundationimport SwiftUI


@Observable final class SheetModel {
    let ref: Reference
    var selection: Set<AnyHashable> = []
    var blocks: [Sheet.Block] { Sheet.with(ref, { $0.blocks }) ?? [] }

    init(_ ref: Reference) { self.ref = ref }

    func block(id: AnyHashable) -> Sheet.Block? {
        Sheet.with(ref, { $0.blocks.first { $0.id == id } }) ?? nil
    }

    func index(for id: AnyHashable) -> Int? {
        Sheet.with(ref, { $0.blocks.firstIndex { $0.id == id } }) ?? nil
    }
    func isSelected(_ id: AnyHashable) -> Bool { selection.contains(id) }
    func select(_ id: AnyHashable?) { selection = id.map { Set([$0]) } ?? [] }

    @discardableResult
    func write(_ text: String, to id: AnyHashable) -> Bool {
        Sheet.update(ref) { sheet -> Bool in
            guard let index = sheet.blocks.firstIndex(where: { $0.id == id }),
                  case .text(let blockID, let previous) = sheet.blocks[index],
                  previous != text
            else { return false }
            sheet.update(.text(blockID, text), at: index)
            return true
        } ?? false
    }

    @discardableResult
    func insert(_ blocks: [Sheet.Block], replacing range: NSRange, in id: AnyHashable) -> (id: AnyHashable, caret: NSRange?)? {
        guard !blocks.isEmpty else { return nil }

        return Sheet.update(ref) { sheet -> (AnyHashable, NSRange?)? in
            guard let index = sheet.blocks.firstIndex(where: { $0.id == id }),
                  case .text(let textID, let text) = sheet.blocks[index]
            else { return nil }

            let length = (text as NSString).length
            let location = min(max(range.location, 0), length)
            let replacementRange = NSRange(location: location, length: min(range.length, length - location))
            let insertedText = blocks.compactMap { block -> String? in
                if case .text(_, let value) = block { return value }
                return nil
            }

            if insertedText.count == blocks.count {
                let replacement = insertedText.joined()
                let next = (text as NSString).replacingCharacters(in: replacementRange, with: replacement)
                let caret = NSRange(location: location + (replacement as NSString).length, length: 0)
                sheet.update(.text(textID, next), at: index)
                return (textID, caret)
            }

            let source = text as NSString
            let before = source.substring(to: location)
            let after = source.substring(from: location + replacementRange.length)
            var insertion = blocks
            if !before.isEmpty { insertion.insert(.text(textID, before), at: 0) }
            if !after.isEmpty { insertion.append(.text(UUID(), after)) }
            sheet.delete(at: index)
            sheet.insert(insertion, at: index)
            return (blocks[blocks.index(before: blocks.endIndex)].id, nil)
        } ?? nil
    }

    @discardableResult
    func update(_ block: Sheet.Block, replacing id: AnyHashable) -> AnyHashable? {
        Sheet.update(ref) { sheet -> AnyHashable? in
            guard let index = sheet.blocks.firstIndex(where: { $0.id == id }) else { return nil }
            sheet.update(block, at: index)
            return sheet.blocks.indices.contains(index) ? sheet.blocks[index].id : nil
        } ?? nil
    }

    @discardableResult
    func delete(_ ids: Set<AnyHashable>) -> AnyHashable? {
        Sheet.update(ref) { sheet -> AnyHashable? in
            let indices = sheet.blocks.indices.filter { ids.contains(sheet.blocks[$0].id) }
            guard let first = indices.first else { return nil }
            for index in indices.reversed() { sheet.delete(at: index) }
            guard !sheet.blocks.isEmpty else { return nil }
            return sheet.blocks[min(max(first - 1, 0), sheet.blocks.count - 1)].id
        } ?? nil
    }

    @discardableResult
    func mergeText(at id: AnyHashable) -> (id: AnyHashable, caret: NSRange)? {
        Sheet.update(ref) { sheet -> (AnyHashable, NSRange)? in
            guard let index = sheet.blocks.firstIndex(where: { $0.id == id }),
                  index > sheet.blocks.startIndex,
                  case .text(_, let text) = sheet.blocks[index],
                  case .text(let previousID, let previous) = sheet.blocks[index - 1]
            else { return nil }

            let caret = NSRange(location: (previous as NSString).length, length: 0)
            sheet.update(.text(previousID, previous + text), at: index - 1)
            sheet.delete(at: index)
            return (previousID, caret)
        } ?? nil
    }

    @discardableResult
    func insertText(at index: Int) -> AnyHashable? {
        let id = UUID()
        return Sheet.update(ref) { sheet -> AnyHashable? in
            let insertion = min(max(index, sheet.blocks.startIndex), sheet.blocks.endIndex)
            sheet.insert(.text(id, ""), at: insertion)
            return sheet.blocks.indices.contains(insertion) ? sheet.blocks[insertion].id : nil
        } ?? nil
    }
}

@MainActor private struct EntryFramesKey: @MainActor PreferenceKey {
    static let defaultValue: [AnyHashable: CGRect] = [:]
    static func reduce(value: inout [AnyHashable: CGRect], nextValue: () -> [AnyHashable: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct SheetView: View {
    @Environment(SheetModel.self) private var sheet
    let editing: AnyHashable?
    let selection: (AnyHashable) -> NSRange?
    let onTextChange: (AnyHashable, String, NSRange) -> Void
    let onSelectionChange: (AnyHashable, NSRange) -> Void
    let onCaretRectChange: (AnyHashable, CGRect) -> Void
    let onViewportRectChange: (AnyHashable, CGRect) -> Void
    let onFocusGained: (AnyHashable) -> Void
    let onEdit: (AnyHashable) -> Void
    let onCommand: (Selector, NSRange, Int) -> Bool
    let onFrameChange: (AnyHashable, CGRect) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(sheet.blocks) { block in
                SheetBlock(
                    block: block,
                    selection: selection(block.id),
                    isEditing: editing == block.id,
                    isSelected: editing == nil && sheet.isSelected(block.id),
                    onTextChange: { onTextChange(block.id, $0, $1) },
                    onSelectionChange: { onSelectionChange(block.id, $0) },
                    onCaretRectChange: { onCaretRectChange(block.id, $0) },
                    onViewportRectChange: { onViewportRectChange(block.id, $0) },
                    onFocusGained: { onFocusGained(block.id) },
                    onEdit: { onEdit(block.id) },
                    onCommand: onCommand
                )
                .id(block.id)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: EntryFramesKey.self,
                            value: [block.id: proxy.frame(in: .named("canvas"))]
                        )
                    }
                }
            }
        }
        .onPreferenceChange(EntryFramesKey.self) { frames in
            for (id, frame) in frames { onFrameChange(id, frame) }
        }
    }
}
