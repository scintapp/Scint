import Foundation
import SwiftUI


/// A stretch of the document that renders as one view.
///
/// Contiguous text blocks share a single editor. A block is a line — `Markdown.holdsMultipleLines`
/// is only true of code fences, and `write` splits anything else on newlines — so a run of them is
/// a multi-line string, and the correspondence back is line index to block id.
///
/// This is why the caret works inside a run without help: it is one text view, so movement,
/// selection, and undo are the text view's own. Only crossing a card needs the editor.
enum BlockRun: Identifiable {
    case text(TextRun)
    case card(Material.Block)

    var id: AnyHashable {
        switch self {
            case .text(let run): return run.id
            case .card(let block): return block.id
        }
    }

    static func runs(of blocks: [Material.Block]) -> [BlockRun] {
        var runs: [BlockRun] = []
        var pending: [Material.Block] = []

        for block in blocks {
            if case .text = block { pending.append(block); continue }
            if !pending.isEmpty { runs.append(.text(TextRun(pending))); pending = [] }
            runs.append(.card(block))
        }

        if !pending.isEmpty { runs.append(.text(TextRun(pending))) }
        return runs
    }
}

/// Contiguous text blocks addressed as one string, and the translation both ways.
struct TextRun: Identifiable {
    let blocks: [Material.Block]

    init(_ blocks: [Material.Block]) { self.blocks = blocks }

    var id: AnyHashable { blocks.first?.id ?? AnyHashable(UUID()) }
    var ids: [AnyHashable] { blocks.map(\.id) }
    var text: String { blocks.map(Self.line).joined(separator: "\n") }

    /// The frame is reported under the last block so a click below the document lands at the end of
    /// the run rather than the start of it.
    var frameID: AnyHashable { blocks.last?.id ?? id }

    static func line(_ block: Material.Block) -> String {
        if case .text(_, let text) = block { return text }
        return ""
    }

    /// A caret inside one of the run's blocks, in run coordinates.
    func offset(of id: AnyHashable, _ range: NSRange) -> NSRange? {
        var start = 0
        for block in blocks {
            guard block.id != id else {
                return NSRange(location: start + range.location, length: range.length)
            }
            start += (Self.line(block) as NSString).length + 1
        }
        return nil
    }

    /// The block a run offset falls in, and where in that block.
    func locate(_ location: Int) -> (id: AnyHashable, range: NSRange)? {
        var start = 0
        for block in blocks {
            let length = (Self.line(block) as NSString).length
            if location <= start + length {
                return (block.id, NSRange(location: max(0, location - start), length: 0))
            }
            start += length + 1
        }
        guard let last = blocks.last else { return nil }
        return (last.id, NSRange(location: (Self.line(last) as NSString).length, length: 0))
    }
}

struct MaterialView: View {
    @Environment(DocumentModel.self) private var material
    let selection: EditorSelection
    let onRunChange: ([AnyHashable], String, NSRange) -> Void
    let onRunSelectionChange: ([AnyHashable], NSRange) -> Void
    let onRunCommand: ([AnyHashable], Selector, NSRange, Int) -> Bool
    let onRunFocusGained: ([AnyHashable]) -> Void
    let onCaretRectChange: (AnyHashable, CGRect) -> Void
    let onFocusGained: (AnyHashable) -> Void
    let onEdit: (AnyHashable, CGRect) -> Void
    let onCommand: (Selector, NSRange, Int) -> Bool
    let onFrames: ([AnyHashable: CGRect]) -> Void

    private func caret(in run: TextRun) -> NSRange? {
        guard let editing = selection.editing, let range = selection.range else { return nil }
        return run.offset(of: editing, range)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Style.Spacing.md) {
            ForEach(BlockRun.runs(of: material.blocks)) { entry in
                switch entry {
                    case .text(let run):
                        EditorInput(
                            id: run.id,
                            ids: run.ids,
                            text: run.text,
                            selection: caret(in: run),
                            isEditing: run.ids.contains { $0 == selection.editing },
                            onTextChange: { onRunChange(run.ids, $0, $1) },
                            onSelectionChange: { onRunSelectionChange(run.ids, $0) },
                            onCaretRectChange: { onCaretRectChange(selection.editing ?? run.id, $0) },
                            onFocusGained: { onRunFocusGained(run.ids) },
                            onCommand: { onRunCommand(run.ids, $0, $1, $2) }
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .background {
                            Style.Shape.medium.fill(
                                !selection.isEditing && run.ids.contains(where: selection.isSelected)
                                ? Color.primary.opacity(Style.Opacity.hairline)
                                : Color.clear
                            )
                        }
                        .id(run.id)
                        .background { frameReader(run.frameID) }

                    case .card(let block):
                        MaterialCard(
                            block: block,
                            isSelected: !selection.isEditing && selection.isSelected(block.id),
                            onFocusGained: { onFocusGained(block.id) },
                            onEdit: { onEdit(block.id, $0) },
                            onCommand: onCommand
                        )
                        .id(block.id)
                        .background { frameReader(block.id) }
                }
            }
        }
        // The preference carries every rendered run, reduced across the whole subtree, so it is a
        // complete snapshot rather than a delta. Merging it into a long-lived dictionary is what let
        // frames outlive their blocks; assigning it makes the map the rendered set by construction.
        .onPreferenceChange(EntryPanelsKey.self) { frames in onFrames(frames) }
    }

    private func frameReader(_ id: AnyHashable) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(key: EntryPanelsKey.self, value: [id: proxy.frame(in: .named("canvas"))])
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

    /// Reconciles a run's edited text back onto its blocks, one line per block.
    ///
    /// Ids are kept positionally so the caret survives an edit: line *n* stays block *n* and is
    /// rewritten in place, extra lines become new blocks, and lines that went away take their
    /// blocks with them. Returns the run's block ids in order.
    @discardableResult
    func replaceRun(_ ids: [AnyHashable], with lines: [String]) -> [AnyHashable] {
        structural {
            Material.update(ref) { material -> [AnyHashable] in
                guard let start = material.blocks.firstIndex(where: { $0.id == ids.first }) else { return [] }
                var result: [AnyHashable] = []

                for (offset, line) in lines.enumerated() {
                    let index = start + offset
                    if offset < ids.count, index < material.blocks.endIndex, material.blocks[index].id == ids[offset] {
                        if Self.text(of: material.blocks[index]) != line {
                            material.update(.text(ids[offset] as? UUID ?? UUID(), line), at: index)
                        }
                        result.append(material.blocks[index].id)
                    } else {
                        let id = UUID()
                        material.insert(.text(id, line), at: index)
                        result.append(AnyHashable(id))
                    }
                }

                for index in stride(from: start + ids.count - 1, through: start + lines.count, by: -1)
                where material.blocks.indices.contains(index) {
                    material.delete(at: index)
                }

                return result
            } ?? []
        } ?? []
    }

    private static func text(of block: Material.Block) -> String? {
        if case .text(_, let text) = block { return text }
        return nil
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
