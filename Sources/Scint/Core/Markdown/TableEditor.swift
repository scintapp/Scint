import Foundation
import SwiftUI
import ScintComponents

extension Markdown {
    struct Table {
        struct Column: Identifiable {
            let id: Int
            var title: String
            var alignment: ColumnAlignment
        }

        struct Row: Identifiable {
            let id: Int
            var cells: [String]
        }

        var columns: [Column]
        var rows: [Row]

        init?(_ chunk: String) {
            let lines = chunk.split(whereSeparator: \.isNewline).map(String.init)
            guard lines.count >= 2,
                  let header = Markdown.tableCells(lines[0]),
                  let delimiters = Markdown.tableCells(lines[1]),
                  header.count == delimiters.count,
                  let alignments = Markdown.tableAlignments(delimiters)
            else { return nil }
            columns = header.indices.map { Column(id: $0, title: header[$0], alignment: alignments[$0]) }
            rows = lines.dropFirst(2).prefix { Markdown.tableCells($0) != nil }.compactMap(Markdown.tableCells).enumerated().map {
                Row(id: $0.offset, cells: Array(($0.element + Array(repeating: "", count: header.count)).prefix(header.count)))
            }
        }

        var markdown: String {
            let line = { (cells: [String]) in
                "| " + cells.map { $0.replacingOccurrences(of: "|", with: "\\|") }.joined(separator: " | ") + " |"
            }
            let delimiters = columns.map {
                switch $0.alignment {
                    case .leading: "---"
                    case .center: ":---:"
                    case .trailing: "---:"
                }
            }
            return ([line(columns.map(\.title)), line(delimiters)] + rows.map { line($0.cells) }).joined(separator: "\n")
        }
    }
}

struct TableEditor: View {
    struct Cell: Hashable { let row: Int; let column: Int }

    @Binding var chunk: String
    @FocusState private var editing: Cell?

    init(_ chunk: Binding<String>) { _chunk = chunk }

    var table: Markdown.Table? { Markdown.Table(chunk) }

    var body: some View {
        if let table {
            Grid(alignment: .topLeading, horizontalSpacing: 0.75, verticalSpacing: 0.75) {
                GridRow {
                    ForEach(table.columns) { column in
                        cell(Cell(row: -1, column: column.id), text: column.title, alignment: column.alignment, font: Typography.Prose.tableHeader) {
                            guard var edited = Markdown.Table(chunk) else { return }
                            edited.columns[column.id].title = $0
                            chunk = edited.markdown
                        }
                    }
                }
                ForEach(table.rows) { row in
                    GridRow {
                        ForEach(table.columns) { column in
                            cell(Cell(row: row.id, column: column.id), text: row.cells[column.id], alignment: column.alignment, font: Typography.Prose.text) {
                                guard var edited = Markdown.Table(chunk) else { return }
                                edited.rows[row.id].cells[column.id] = $0
                                chunk = edited.markdown
                            }
                        }
                    }
                }
            }
            .background(Style.Background.selection)
            .clipShape(Style.Shape.control)
            .overlay {
                Style.Shape.control.strokeBorder(Style.Background.selection, lineWidth: 0.75)
            }
        }
    }

    private func current(_ id: Cell) -> String? {
        guard let table = Markdown.Table(chunk) else { return nil }
        if id.row < 0 { return table.columns.indices.contains(id.column) ? table.columns[id.column].title : nil }
        guard table.rows.indices.contains(id.row), table.rows[id.row].cells.indices.contains(id.column) else { return nil }
        return table.rows[id.row].cells[id.column]
    }

    private func cell(_ id: Cell, text: String, alignment: Markdown.ColumnAlignment, font: NSFont, onChange: @escaping (String) -> Void) -> some View {
        let edge: Alignment = switch alignment {
            case .leading: .topLeading
            case .center: .top
            case .trailing: .topTrailing
        }
        return ZStack(alignment: edge) {
            TextField("", text: .init(get: { current(id) ?? text }, set: onChange), axis: .vertical)
                .textFieldStyle(.plain)
                .focused($editing, equals: id)
                .opacity(editing == id ? 1 : 0)
            if editing != id {
                Text((try? AttributedString(markdown: text)) ?? AttributedString(text))
                    .allowsHitTesting(false)
            }
        }
        .font(Font(font as CTFont))
        .multilineTextAlignment(alignment == .center ? .center : alignment == .trailing ? .trailing : .leading)
        .padding(Typography.Prose.tableCellPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge)
        .background(Style.Background.canvas)
        .contentShape(Rectangle())
        .onTapGesture { editing = id }
    }
}

#Preview {
    @Previewable @State var chunk = """
    | Space | Owner | Documents | Status |
    | --- | :---: | ---: | --- |
    | Research | Tim | 12 | Active |
    | Editor | Claude | 4 | Draft |
    | Library | Tim | 27 | Complete |
    | Short row | Tim |
    """

    VStack(spacing: 0) {
        TableEditor($chunk)

        Text(chunk)
            .font(.system(size: 11, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
    }
    .frame(width: 560, height: 420)
}
