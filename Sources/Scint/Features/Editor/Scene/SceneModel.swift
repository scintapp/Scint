
import Foundation
import SwiftUI


@Observable final class SceneModel {
    let ref: Reference
    var selection: Set<AnyHashable> = []
    var blocks: [Scene.Block] { Scene.with(ref, { $0.blocks }) ?? [] }

    init(_ ref: Reference) { self.ref = ref }

    func block(id: AnyHashable) -> Scene.Block? {
        Scene.with(ref, { $0.blocks.first { $0.id == id } }) ?? nil
    }

    func index(for id: AnyHashable) -> Int? {
        Scene.with(ref, { $0.blocks.firstIndex { $0.id == id } }) ?? nil
    }
    func isSelected(_ id: AnyHashable) -> Bool { selection.contains(id) }
    func select(_ id: AnyHashable?) { selection = id.map { Set([$0]) } ?? [] }

    @discardableResult
    func write(_ text: String, to id: AnyHashable) -> Bool {
        Scene.update(ref) { scene -> Bool in
            guard let index = scene.blocks.firstIndex(where: { $0.id == id }),
                  case .text(let blockID, let previous) = scene.blocks[index],
                  previous != text
            else { return false }
            scene.update(.text(blockID, text), at: index)
            return true
        } ?? false
    }

    @discardableResult
    func insert(_ blocks: [Scene.Block], replacing range: NSRange, in id: AnyHashable) -> (id: AnyHashable, caret: NSRange?)? {
        guard !blocks.isEmpty else { return nil }

        return Scene.update(ref) { scene -> (AnyHashable, NSRange?)? in
            guard let index = scene.blocks.firstIndex(where: { $0.id == id }),
                  case .text(let textID, let text) = scene.blocks[index]
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
                scene.update(.text(textID, next), at: index)
                return (textID, caret)
            }

            let source = text as NSString
            let before = source.substring(to: location)
            let after = source.substring(from: location + replacementRange.length)
            var insertion = blocks
            if !before.isEmpty { insertion.insert(.text(textID, before), at: 0) }
            if !after.isEmpty { insertion.append(.text(UUID(), after)) }
            scene.delete(at: index)
            scene.insert(insertion, at: index)
            return (blocks[blocks.index(before: blocks.endIndex)].id, nil)
        } ?? nil
    }

    @discardableResult
    func update(_ block: Scene.Block, replacing id: AnyHashable) -> AnyHashable? {
        Scene.update(ref) { scene -> AnyHashable? in
            guard let index = scene.blocks.firstIndex(where: { $0.id == id }) else { return nil }
            scene.update(block, at: index)
            return scene.blocks.indices.contains(index) ? scene.blocks[index].id : nil
        } ?? nil
    }

    @discardableResult
    func delete(_ ids: Set<AnyHashable>) -> AnyHashable? {
        Scene.update(ref) { scene -> AnyHashable? in
            let indices = scene.blocks.indices.filter { ids.contains(scene.blocks[$0].id) }
            guard let first = indices.first else { return nil }
            for index in indices.reversed() { scene.delete(at: index) }
            guard !scene.blocks.isEmpty else { return nil }
            return scene.blocks[min(max(first - 1, 0), scene.blocks.count - 1)].id
        } ?? nil
    }

    @discardableResult
    func mergeText(at id: AnyHashable) -> (id: AnyHashable, caret: NSRange)? {
        Scene.update(ref) { scene -> (AnyHashable, NSRange)? in
            guard let index = scene.blocks.firstIndex(where: { $0.id == id }),
                  index > scene.blocks.startIndex,
                  case .text(_, let text) = scene.blocks[index],
                  case .text(let previousID, let previous) = scene.blocks[index - 1]
            else { return nil }

            let caret = NSRange(location: (previous as NSString).length, length: 0)
            scene.update(.text(previousID, previous + text), at: index - 1)
            scene.delete(at: index)
            return (previousID, caret)
        } ?? nil
    }

    @discardableResult
    func insertText(at index: Int) -> AnyHashable? {
        let id = UUID()
        return Scene.update(ref) { scene -> AnyHashable? in
            let insertion = min(max(index, scene.blocks.startIndex), scene.blocks.endIndex)
            scene.insert(.text(id, ""), at: insertion)
            return scene.blocks.indices.contains(insertion) ? scene.blocks[insertion].id : nil
        } ?? nil
    }
}

@MainActor private struct EntryPanelsKey: @MainActor PreferenceKey {
    static let defaultValue: [AnyHashable: CGRect] = [:]
    static func reduce(value: inout [AnyHashable: CGRect], nextValue: () -> [AnyHashable: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct SceneView: View {
    @Environment(SceneModel.self) private var scene
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
        VStack(alignment: .leading) {
            ForEach(scene.blocks) { block in
                SceneBlock(
                    block: block,
                    selection: selection(block.id),
                    isEditing: editing == block.id,
                    isSelected: editing == nil && scene.isSelected(block.id),
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
