import Foundation


/// Where the user is.
///
/// One value, not four. This used to be `EditorState.editing`, `DocumentModel.selection`,
/// `EditorFocusCoordinator.targetID` and the window's first responder, each set independently by
/// five different methods and reconciled by hand — which is what the focus retry loops existed to
/// paper over. First responder now derives from this, one way, and nothing votes.
enum EditorSelection: Equatable {
    case none

    /// A component card is selected. Arrows move between blocks, Return opens a text block after
    /// it, Backspace deletes it.
    case block(AnyHashable)

    /// Text is being edited, with the caret at `range` in source coordinates.
    case caret(AnyHashable, NSRange)

    /// Several blocks are selected at once. Backspace deletes them, Escape clears, arrows collapse
    /// to an edge. Reached by cmd-A once the block being edited is already fully selected.
    case blocks(Set<AnyHashable>)

    /// The block the user is on, whether or not it is being edited.
    var id: AnyHashable? {
        switch self {
            case .none, .blocks: return nil
            case .block(let id): return id
            case .caret(let id, _): return id
        }
    }

    /// Every block the selection covers, in no particular order.
    var ids: Set<AnyHashable> {
        switch self {
            case .none: return []
            case .blocks(let ids): return ids
            case .block(let id), .caret(let id, _): return [id]
        }
    }

    /// The block being edited, or nil when a card is merely selected.
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

/// What a key means in the editor.
///
/// One vocabulary, resolved in one place. The behaviour used to be spread across a selector switch
/// in the state, three overrides on the text view, five more on the block responder, and the
/// delegate — with two of those paths reaching the same handler for the same key.
enum EditorCommand: Equatable {
    /// Return on a card: open a text block after it.
    case insertBlockAfter
    /// Backspace on a card.
    case deleteBlock
    /// Tab / Shift-Tab inside a list item.
    case nest(Int)
    /// Arrows past the edge of a block.
    case step(Int)
    /// Land on an inline component rather than stepping over it.
    case selectReference(NSRange)
    /// Escape.
    case dismiss
    /// Cmd-A past the end of a single block: every block at once.
    case selectAllBlocks
}
