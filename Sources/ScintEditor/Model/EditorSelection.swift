import Foundation


enum EditorSelection: Equatable {
    case none
    case block(AnyHashable)
    case caret(AnyHashable, NSRange)
    case blocks(Set<AnyHashable>)

    var id: AnyHashable? {
        switch self {
            case .none, .blocks: return nil
            case .block(let id): return id
            case .caret(let id, _): return id
        }
    }

    var ids: Set<AnyHashable> {
        switch self {
            case .none: return []
            case .blocks(let ids): return ids
            case .block(let id), .caret(let id, _): return [id]
        }
    }

    var editing: AnyHashable? {
        guard case .caret(let id, _) = self else { return nil }
        return id
    }

    var range: NSRange? {
        guard case .caret(_, let range) = self else { return nil }
        return range
    }

    var isEditing: Bool { editing != nil }

    func caret(in id: AnyHashable) -> NSRange? {
        guard case .caret(let current, let range) = self, current == id else { return nil }
        return range
    }

    func isSelected(_ id: AnyHashable) -> Bool {
        if case .blocks(let ids) = self { return ids.contains(id) }
        return self.id == id
    }
}

enum EditorCommand: Equatable {
    case insertBlockAfter
    case deleteBlock
    case nest(Int)
    case step(Int)
    case selectReference(NSRange)
    case dismiss
    case selectAllBlocks
}
