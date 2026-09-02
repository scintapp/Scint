import Foundation
import SwiftUI


struct MaterialView: View {
    @Environment(DocumentModel.self) private var material
    let selection: EditorSelection
    let onTextChange: (AnyHashable, String, NSRange) -> Void
    let onSelectionChange: (AnyHashable, NSRange) -> Void
    let onCaretRectChange: (AnyHashable, CGRect) -> Void
    let onFocusGained: (AnyHashable) -> Void
    let onEdit: (AnyHashable, CGRect) -> Void
    let onCommand: (Selector, NSRange, Int) -> Bool
    let onPanelChange: (AnyHashable, CGRect) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Style.Spacing.md) {
            ForEach(material.blocks) { block in
                MaterialCard(
                    block: block,
                    selection: selection.caret(in: block.id),
                    isEditing: selection.editing == block.id,
                    isSelected: !selection.isEditing && selection.isSelected(block.id),
                    onTextChange: { onTextChange(block.id, $0, $1) },
                    onSelectionChange: { onSelectionChange(block.id, $0) },
                    onCaretRectChange: { onCaretRectChange(block.id, $0) },
                    onFocusGained: { onFocusGained(block.id) },
                    onEdit: { onEdit(block.id, $0) },
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

@Observable @MainActor final class DocumentModel {
    let ref: Reference
    var blocks: [Material.Block] { Material.with(ref, { $0.blocks }) ?? [] }
    let undoManager = UndoManager()

    init(_ ref: Reference) { self.ref = ref }

    private func structural<T>(_ body: () -> T) -> T {
        let before = blocks
        let result = body()
        if blocks != before { registerUndo(restoring: before) }
        return result
    }

    private func registerUndo(restoring snapshot: [Material.Block]) {
        undoManager.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated {
                let redo = model.blocks
                model.restore(snapshot)
                model.registerUndo(restoring: redo)
            }
        }
    }

    private func restore(_ snapshot: [Material.Block]) {
        Material.update(ref) { material in
            for index in material.blocks.indices.reversed() { material.delete(at: index) }
            material.insert(snapshot, at: 0)
        }
    }

    func block(id: AnyHashable) -> Material.Block? {
        Material.with(ref, { $0.blocks.first { $0.id == id } }) ?? nil
    }

    func index(for id: AnyHashable) -> Int? {
        Material.with(ref, { $0.blocks.firstIndex { $0.id == id } }) ?? nil
    }

    @discardableResult
    func inlineReferenceBlocks() -> Bool {
        Material.update(ref) { material -> Bool in
            var changed = false

            for index in material.blocks.indices {
                let reference: Reference
                switch material.blocks[index] {
                    case .artifact(let ref), .command(let ref), .material(let ref): reference = ref
                    case .task, .text: continue
                }
                guard let link = ReferenceURL.markdown(for: reference) else { continue }
                material.update(.text(UUID(), link), at: index)
                changed = true
            }

            return changed
        } ?? false
    }

    @discardableResult
    func write(_ text: String, to id: AnyHashable, structural isStructural: Bool = false) -> Bool {
        guard isStructural else { return performWrite(text, to: id) }
        return structural { performWrite(text, to: id) }
    }

    private func performWrite(_ text: String, to id: AnyHashable) -> Bool {
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
        return structural {
            guard !blocks.isEmpty else { return nil }

            return Material.update(ref) { material -> (AnyHashable, NSRange?)? in
                guard
                    let index = material.blocks.firstIndex(where: { $0.id == id }),
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
    }

    @discardableResult
    func update(_ block: Material.Block, replacing id: AnyHashable) -> AnyHashable? {
        return structural {
            Material.update(ref) { material -> AnyHashable? in
                guard let index = material.blocks.firstIndex(where: { $0.id == id }) else { return nil }
                material.update(block, at: index)
                return material.blocks.indices.contains(index) ? material.blocks[index].id : nil
            } ?? nil
        }
    }

    @discardableResult
    func delete(_ ids: Set<AnyHashable>) -> AnyHashable? {
        return structural {
            Material.update(ref) { material -> AnyHashable? in
                let indices = material.blocks.indices.filter { ids.contains(material.blocks[$0].id) }
                guard let first = indices.first else { return nil }
                for index in indices.reversed() { material.delete(at: index) }
                guard !material.blocks.isEmpty else { return nil }
                return material.blocks[min(max(first - 1, 0), material.blocks.count - 1)].id
            } ?? nil
        }
    }

    @discardableResult
    func mergeText(at id: AnyHashable) -> (id: AnyHashable, caret: NSRange)? {
        return structural {
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
    }

    @discardableResult
    func splitText(at id: AnyHashable, range: NSRange, prefix: String) -> (id: AnyHashable, caret: NSRange)? {
        return structural {
            let next = UUID()

            return Material.update(ref) { material -> (AnyHashable, NSRange)? in
                guard let index = material.blocks.firstIndex(where: { $0.id == id }),
                      case .text(let textID, let text) = material.blocks[index]
                else { return nil }

                let source = text as NSString
                let location = min(max(range.location, 0), source.length)
                let length = min(range.length, source.length - location)

                let before = source.substring(to: location)
                let after = source.substring(from: location + length)

                material.update(.text(textID, before), at: index)
                material.insert(.text(next, prefix + after), at: index + 1)

                return (next, NSRange(location: (prefix as NSString).length, length: 0))
            } ?? nil
        }
    }

    @discardableResult
    func replaceText(at id: AnyHashable, with lines: [String]) -> (id: AnyHashable, caret: NSRange)? {
        return structural {
            guard let last = lines.last else { return nil }
            let ids = lines.map { _ in UUID() }

            return Material.update(ref) { material -> (AnyHashable, NSRange)? in
                guard let index = material.blocks.firstIndex(where: { $0.id == id }) else { return nil }
                material.delete(at: index)
                material.insert(zip(ids, lines).map { .text($0, $1) }, at: index)
                return (ids[ids.index(before: ids.endIndex)], NSRange(location: (last as NSString).length, length: 0))
            } ?? nil
        }
    }

    @discardableResult
    func insertText(at index: Int) -> AnyHashable? {
        return structural {
            let id = UUID()
            return Material.update(ref) { material -> AnyHashable? in
                let insertion = min(max(index, material.blocks.startIndex), material.blocks.endIndex)
                material.insert(.text(id, ""), at: insertion)
                return material.blocks.indices.contains(insertion) ? material.blocks[insertion].id : nil
            } ?? nil
        }
    }
}
