import Foundation
import ScintRuntime


/// ScintEdit's structural edits over a document ref.
///
/// Deliberately NOT an extension on `Document`: these are editor verbs carrying editor
/// vocabulary (caret ranges, landings), and the runtime's model does not grow them.
/// Everything here goes through `Document`'s existing public API and nothing else.
enum EditBlocks {
    /// The block that takes focus after an edit, and where its caret enters.
    struct Landing {
        let id: AnyHashable
        var edge: EditEdge = .end
    }

    /// Inserts an empty text block, returning its id. A nil index appends.
    @discardableResult
    static func insertText(_ ref: Reference, at index: Int?) -> AnyHashable {
        let id = UUID()
        Document.update(ref) { $0.insert(.text(id, ""), at: index) }
        return id
    }

    /// Guarantees the document ends in a text block, so there is always somewhere to type.
    @discardableResult
    static func ensureTrailingText(_ ref: Reference) -> AnyHashable {
        if case .text(let id, _)? = Document.with(ref, { $0.blocks.last }) ?? nil { return id }
        return insertText(ref, at: nil)
    }

    /// Returns true only when the text actually changed.
    static func setText(_ ref: Reference, at index: Int, to text: String) -> Bool {
        Document.update(ref) { document -> Bool in
            guard document.blocks.indices.contains(index),
                  case .text(let id, let previous) = document.blocks[index],
                  previous != text
            else { return false }
            document.update(.text(id, text), at: index)
            return true
        } ?? false
    }

    /// Merges a text block into the text block before it.
    static func mergeBackward(_ ref: Reference, at index: Int) -> Landing? {
        Document.update(ref) { document -> Landing? in
            guard document.blocks.indices.contains(index),
                  index > document.blocks.startIndex,
                  case .text(_, let text) = document.blocks[index],
                  case .text(let previousID, let previous) = document.blocks[index - 1]
            else { return nil }
            document.update(.text(previousID, previous + text), at: index - 1)
            document.delete(at: index)
            return Landing(id: previousID, edge: .offset((previous as NSString).length))
        } ?? nil
    }

    /// Removes blocks, landing on the one before the first of them.
    static func remove(_ ref: Reference, ids: Set<AnyHashable>) -> Landing? {
        Document.update(ref) { document -> Landing? in
            guard let first = document.blocks.firstIndex(where: { ids.contains($0.id) }) else { return nil }
            for index in document.blocks.indices.reversed() where ids.contains(document.blocks[index].id) {
                document.delete(at: index)
            }
            guard !document.blocks.isEmpty else { return nil }
            return Landing(id: document.blocks[min(max(first - 1, 0), document.blocks.count - 1)].id)
        } ?? nil
    }

    /// Replaces a range inside one text block with more text, staying in that block.
    static func spliceText(_ ref: Reference, at index: Int, replacing range: NSRange, with replacement: String) -> Landing? {
        Document.update(ref) { document -> Landing? in
            guard document.blocks.indices.contains(index),
                  case .text(let id, let text) = document.blocks[index]
            else { return nil }
            let target = clamped(range, in: text)
            document.update(.text(id, (text as NSString).replacingCharacters(in: target, with: replacement)), at: index)
            return Landing(id: id, edge: .offset(target.location + (replacement as NSString).length))
        } ?? nil
    }

    /// Replaces a range inside a text block with blocks, splitting it around them.
    static func splice(_ ref: Reference, at index: Int, replacing range: NSRange, with blocks: [Document.Block]) -> AnyHashable? {
        Document.update(ref) { document -> AnyHashable? in
            guard document.blocks.indices.contains(index),
                  case .text(let id, let text) = document.blocks[index]
            else { return nil }
            let source = text as NSString
            let target = clamped(range, in: text)
            let before = source.substring(to: target.location)
            let after = source.substring(from: target.location + target.length)

            var replacement: [Document.Block] = []
            if !before.isEmpty { replacement.append(.text(id, before)) }
            replacement.append(contentsOf: blocks)
            if !after.isEmpty { replacement.append(.text(UUID(), after)) }

            document.delete(at: index)
            document.insert(replacement, at: index)
            return blocks.last?.id
        } ?? nil
    }

    private static func clamped(_ range: NSRange, in string: String) -> NSRange {
        let length = (string as NSString).length
        let location = min(max(range.location, 0), length)
        return NSRange(location: location, length: min(max(range.length, 0), length - location))
    }
}
