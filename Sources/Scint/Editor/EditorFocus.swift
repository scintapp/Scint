import Foundation
import Observation


@Observable @MainActor final class EditorFocus {
    struct Item: Identifiable, Equatable {
        enum Kind: Equatable {
            case block
            case editor
        }

        let id: UUID
        let kind: Kind
        let title: String

        init(id: UUID = UUID(), kind: Kind, title: String) {
            self.id = id
            self.kind = kind
            self.title = title
        }

        var isEditor: Bool { kind == .editor }
    }

    struct Row: Identifiable, Equatable {
        let id: UUID
        var items: [Item]
        let isNested: Bool

        init(id: UUID = UUID(), items: [Item], isNested: Bool = false) {
            self.id = id
            self.items = items
            self.isNested = isNested
        }
    }

    enum Offset {
        case previous
        case next
        case left
        case right

        var rowDistance: Int {
            switch self {
            case .previous: -1
            case .next: 1
            case .left, .right: 0
            }
        }

        var columnDistance: Int {
            switch self {
            case .left: -1
            case .right: 1
            case .previous, .next: 0
            }
        }
    }

    var rows: [Row]
    var selectedID: Item.ID?
    var items: [Item] { rows.flatMap(\.items) }
    var focusedID: Item.ID? { selectedID }

    init() {
        let block1 = Item(kind: .block, title: "Block 1")
        let editor1 = Item(kind: .editor, title: "Editor 1")
        let block2 = Item(kind: .block, title: "Block 2")
        let innerBlocks = (1...3).map { Item(kind: .block, title: "Inner \($0)") }
        let editor2 = Item(kind: .editor, title: "Editor 2")
        let editor3 = Item(kind: .editor, title: "Editor 3")

        rows = [
            Row(items: [block1]),
            Row(items: [editor1]),
            Row(items: [block2]),
            Row(items: innerBlocks, isNested: true),
            Row(items: [editor2]),
            Row(items: [editor3])
        ]
        selectedID = block1.id
    }

    @discardableResult
    func moveSelection(id: Item.ID, offset: Offset) -> Bool {
        guard selectedID == id,
              let rowIndex = rows.firstIndex(where: { row in
                  row.items.contains(where: { $0.id == id })
              }),
              let columnIndex = rows[rowIndex].items.firstIndex(where: { $0.id == id })
        else { return false }

        let nextRowIndex = rowIndex + offset.rowDistance
        guard rows.indices.contains(nextRowIndex) else { return false }

        let nextColumnIndex = offset.rowDistance == 0
            ? columnIndex + offset.columnDistance
            : min(columnIndex, rows[nextRowIndex].items.count - 1)
        guard rows[nextRowIndex].items.indices.contains(nextColumnIndex) else { return false }

        selectedID = rows[nextRowIndex].items[nextColumnIndex].id
        return true
    }

    @discardableResult
    func insert(_ kind: Item.Kind) -> Item.ID {
        let title = kind == .editor ? "New Editor" : "New Block"
        let item = Item(kind: kind, title: title)
        let insertionIndex = selectedID.flatMap { selectedID in
            rows.firstIndex(where: { row in
                row.items.contains(where: { $0.id == selectedID })
            })
        }.map { $0 + 1 } ?? rows.endIndex

        rows.insert(Row(items: [item]), at: insertionIndex)
        selectedID = item.id
        return item.id
    }

    func delete(id: Item.ID) {
        let oldItems = items
        guard let deletedIndex = oldItems.firstIndex(where: { $0.id == id }),
              let rowIndex = rows.firstIndex(where: { row in
                  row.items.contains(where: { $0.id == id })
              }),
              let columnIndex = rows[rowIndex].items.firstIndex(where: { $0.id == id })
        else { return }

        rows[rowIndex].items.remove(at: columnIndex)
        if rows[rowIndex].items.isEmpty {
            rows.remove(at: rowIndex)
        }

        guard selectedID == id else { return }
        let remainingItems = items
        selectedID = remainingItems.isEmpty
            ? nil
            : remainingItems[min(deletedIndex, remainingItems.count - 1)].id
    }
}
