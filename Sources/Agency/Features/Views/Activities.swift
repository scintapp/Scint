import AgencyRuntime
import SwiftUI


struct RowData: Identifiable {
    let context: Composition
    var id: Reference { context.boundary }
}

struct TableRow: View {
    let context: Composition
    let columns: [TableColumn]
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        TableRowSurface(selected: selected, action: onSelect) {
            TableCell(column: columns[0]) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Space.with(context.boundary, { $0 })?.name ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.86))
                            .lineLimit(1)

                        Text(Space.with(context.boundary, { $0 })?.name ?? "")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            TableCell(column: columns[1]) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Space.with(context.boundary, { $0 })?.name ?? "")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.8))
                        .lineLimit(1)

                    Text(Space.with(context.boundary, { $0 })?.name ?? "")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            TableCell(column: columns[2]) {
                TableBadge(title: "—", color: Design.Tint.ready)
            }
        }
    }
}

struct Activities: View {
    @Environment(AgencyModel.self) var agency

    var rows: [RowData] {
        Runtime.shared.context()
            .filter { $0.service.type is Service.Type || Transcript.with($0.transcript, { !$0.entries.isEmpty }) == true }
            .sorted { Space.with($0.boundary, { $0.name }) ?? "" < Space.with($1.boundary, { $0.name }) ?? "" }
            .map(RowData.init)
    }

    static let columns: [TableColumn] = [
        .init(title: "Process", width: 320),
        .init(title: "Journal"),
        .init(title: "State", width: 80)
    ]

    var body: some View {
        TableLayout(
            columns: Self.columns,
            sections: rows.isEmpty ? [] : [TableSectionData(id: "processes", title: "Processes", detail: "\(rows.count) tracked", rows: rows)]
        ) { row in
            TableRow(
                context: row.context,
                columns: Self.columns,
                selected: agency.session.selected(row.context.boundary),
                onSelect: { agency.select(row.context.boundary) }
            )
        }
    }
}
