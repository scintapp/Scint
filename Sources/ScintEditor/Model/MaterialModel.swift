import Foundation
import SwiftUI


struct MaterialView: View {
    @Environment(MaterialModel.self) private var material
    let editing: AnyHashable?
    let selection: (AnyHashable) -> NSRange?
    let onTextChange: (AnyHashable, String, NSRange) -> Void
    let onSelectionChange: (AnyHashable, NSRange) -> Void
    let onCaretRectChange: (AnyHashable, CGRect) -> Void
    let onViewportRectChange: (AnyHashable, CGRect) -> Void
    let onFocusGained: (AnyHashable) -> Void
    let onEdit: (AnyHashable) -> Void
    let onCommand: (Selector, NSRange, Int) -> Bool
    let onPanelChange: (AnyHashable, CGRect) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Style.Spacing.md) {
            ForEach(material.blocks) { block in
                MaterialCard(
                    block: block,
                    selection: selection(block.id),
                    isEditing: editing == block.id,
                    isSelected: editing == nil && material.isSelected(block.id),
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
                            key: EntryPanelsKey.self,
                            value: [block.id: proxy.frame(in: .named("canvas"))]
                        )
                    }
                }
            }
        }
        .onPreferenceChange(EntryPanelsKey.self) { frames in
            for (id, frame) in frames { onPanelChange(id, frame) }
        }
    }
}

@MainActor private struct EntryPanelsKey: @MainActor PreferenceKey {
    static let defaultValue: [AnyHashable: CGRect] = [:]
    static func reduce(value: inout [AnyHashable: CGRect], nextValue: () -> [AnyHashable: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

@Observable final class MaterialModel {
    let ref: Reference
    var selection: Set<AnyHashable> = []
    var blocks: [Material.Block] { Material.with(ref, { $0.blocks }) ?? [] }

    init(_ ref: Reference) { self.ref = ref }

    func block(id: AnyHashable) -> Material.Block? {
        Material.with(ref, { $0.blocks.first { $0.id == id } }) ?? nil
    }

    func index(for id: AnyHashable) -> Int? {
        Material.with(ref, { $0.blocks.firstIndex { $0.id == id } }) ?? nil
    }
    func isSelected(_ id: AnyHashable) -> Bool { selection.contains(id) }
    func select(_ id: AnyHashable?) { selection = id.map { Set([$0]) } ?? [] }

    @discardableResult
    func write(_ text: String, to id: AnyHashable) -> Bool {
        Material.update(ref) { material -> Bool in
            guard let index = material.blocks.firstIndex(where: { $0.id == id }),
                  case .text(let blockID, let previous) = material.blocks[index],
                  previous != text
            else { return false }
            material.update(.text(blockID, text), at: index)
            return true
        } ?? false
    }

    @discardableResult
    func insert(_ blocks: [Material.Block], replacing range: NSRange, in id: AnyHashable) -> (id: AnyHashable, caret: NSRange?)? {
        guard !blocks.isEmpty else { return nil }

        return Material.update(ref) { material -> (AnyHashable, NSRange?)? in
            guard let index = material.blocks.firstIndex(where: { $0.id == id }),
                  case .text(let textID, let text) = material.blocks[index]
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
                material.update(.text(textID, next), at: index)
                return (textID, caret)
            }

            let source = text as NSString
            let before = source.substring(to: location)
            let after = source.substring(from: location + replacementRange.length)
            var insertion = blocks
            if !before.isEmpty { insertion.insert(.text(textID, before), at: 0) }
            if !after.isEmpty { insertion.append(.text(UUID(), after)) }
            material.delete(at: index)
            material.insert(insertion, at: index)
            return (blocks[blocks.index(before: blocks.endIndex)].id, nil)
        } ?? nil
    }

    @discardableResult
    func update(_ block: Material.Block, replacing id: AnyHashable) -> AnyHashable? {
        Material.update(ref) { material -> AnyHashable? in
            guard let index = material.blocks.firstIndex(where: { $0.id == id }) else { return nil }
            material.update(block, at: index)
            return material.blocks.indices.contains(index) ? material.blocks[index].id : nil
        } ?? nil
    }

    @discardableResult
    func delete(_ ids: Set<AnyHashable>) -> AnyHashable? {
        Material.update(ref) { material -> AnyHashable? in
            let indices = material.blocks.indices.filter { ids.contains(material.blocks[$0].id) }
            guard let first = indices.first else { return nil }
            for index in indices.reversed() { material.delete(at: index) }
            guard !material.blocks.isEmpty else { return nil }
            return material.blocks[min(max(first - 1, 0), material.blocks.count - 1)].id
        } ?? nil
    }

    @discardableResult
    func mergeText(at id: AnyHashable) -> (id: AnyHashable, caret: NSRange)? {
        Material.update(ref) { material -> (AnyHashable, NSRange)? in
            guard let index = material.blocks.firstIndex(where: { $0.id == id }),
                  index > material.blocks.startIndex,
                  case .text(_, let text) = material.blocks[index],
                  case .text(let previousID, let previous) = material.blocks[index - 1]
            else { return nil }

            let caret = NSRange(location: (previous as NSString).length, length: 0)
            material.update(.text(previousID, previous + text), at: index - 1)
            material.delete(at: index)
            return (previousID, caret)
        } ?? nil
    }

    @discardableResult
    func insertText(at index: Int) -> AnyHashable? {
        let id = UUID()
        return Material.update(ref) { material -> AnyHashable? in
            let insertion = min(max(index, material.blocks.startIndex), material.blocks.endIndex)
            material.insert(.text(id, ""), at: insertion)
            return material.blocks.indices.contains(insertion) ? material.blocks[insertion].id : nil
        } ?? nil
    }
}
