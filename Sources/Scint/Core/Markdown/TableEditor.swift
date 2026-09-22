import Foundation
import SwiftUI


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
    @Binding var chunk: String

    init(_ chunk: Binding<String>) { _chunk = chunk }

    var table: Markdown.Table? { Markdown.Table(chunk) }

    var body: some View {
        if let table {
            Table(table.rows) {
                TableColumnForEach(table.columns) { column in
                    TableColumn(column.title) { row in
                        TextField("", text: .init(get: { row.cells[column.id] }, set: {
                            var edited = table
                            edited.rows[row.id].cells[column.id] = $0
                            chunk = edited.markdown
                        }))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(column.alignment == .center ? .center : column.alignment == .trailing ? .trailing : .leading)
                    }
                    .alignment(column.alignment == .center ? .center : column.alignment == .trailing ? .trailing : .leading)
                }
            }
        }
    }
}
