import SwiftUI


enum TableStyle: Hashable {
    case card
    case plain
}

struct TableBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color.opacity(0.92))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .glassEffect(.regular.tint(color.opacity(0.14)), in: Capsule(style: .continuous))
    }
}

struct TableHeader: View {
    let columns: [TableColumn]

    var body: some View {
        HStack {
            ForEach(columns) { column in
                TableCell(column: column) {
                }
            }
        }
    }
}

struct TableColumn: Identifiable, Hashable {
    enum CellAlignment: Hashable {
        case leading
        case center
        case trailing

        var frameAlignment: Alignment {
            switch self {
            case .leading: .leading
            case .center: .center
            case .trailing: .trailing
            }
        }

        var textAlignment: TextAlignment {
            switch self {
            case .leading: .leading
            case .center: .center
            case .trailing: .trailing
            }
        }
    }

    let id: String
    let title: String
    let width: CGFloat?
    let alignment: CellAlignment

    init(id: String? = nil, title: String, width: CGFloat? = nil, alignment: CellAlignment = .leading) {
        self.id = id ?? title.lowercased().replacingOccurrences(of: " ", with: "-")
        self.title = title
        self.width = width
        self.alignment = alignment
    }
}

struct TableSectionData<Row: Identifiable>: Identifiable {
    let id: String
    let title: String?
    let detail: String?
    let rows: [Row]

    init(id: String? = nil, title: String? = nil, detail: String? = nil, rows: [Row]) {
        self.id = id ?? title?.lowercased().replacingOccurrences(of: " ", with: "-") ?? UUID().uuidString
        self.title = title
        self.detail = detail
        self.rows = rows
    }
}

struct TableSectionHeader: View {
    let title: String?
    let detail: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                if let title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.8))
                }

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(alignment: .leading)
            Spacer(minLength: 0)
        }
        .frame(height: 48, alignment: .leading)
        .padding(8)
    }
}

struct TableRowSurface<Content: View>: View {
    @State private var isHovered = false
    @ViewBuilder let content: () -> Content
    let selected: Bool
    let action: (() -> Void)?

    init(selected: Bool = false, action: (() -> Void)? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.selected = selected
        self.action = action
        self.content = content
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { rowBody } .buttonStyle(.plain)
            } else {
                rowBody
            }
        }
        .onHover { isHovered = $0 }
    }

    private var rowBody: some View {
        HStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selected ? Color.white.opacity(0.03) : isHovered ? Color.white.opacity(0.03) : Color.white.opacity(0))
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TableCell<Content: View>: View {
    let column: TableColumn
    @ViewBuilder let content: () -> Content

    init(column: TableColumn, @ViewBuilder content: @escaping () -> Content) {
        self.column = column
        self.content = content
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: column.alignment.frameAlignment)
            .frame(width: column.width, alignment: column.alignment.frameAlignment)
    }
}

struct TableLayout<Row: Identifiable, RowContent: View>: View {
    let columns: [TableColumn]
    let sections: [TableSectionData<Row>]
    @ViewBuilder let rowContent: (Row) -> RowContent

    init( columns: [TableColumn], sections: [TableSectionData<Row>], @ViewBuilder rowContent: @escaping (Row) -> RowContent) {
        self.columns = columns
        self.sections = sections
        self.rowContent = rowContent
    }

    var body: some View {
        Group {
            tableContent
        }
    }

    private var tableContent: some View {
        VStack(spacing: 0) {
            if !columns.isEmpty {
                TableHeader(columns: columns)
            }

            VStack(spacing: 0) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    if index > 0 {
                    }

                    if section.title != nil || section.detail != nil {
                        TableSectionHeader(title: section.title, detail: section.detail)
                    }

                    VStack {
                        ForEach(Array(section.rows.enumerated()), id: \.element.id) { rowIndex, row in
                            rowContent(row)

                        }
                    }
                }
            }
        }
    }
}
