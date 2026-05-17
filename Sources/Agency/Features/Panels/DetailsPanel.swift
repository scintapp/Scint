import AgencyRuntime
import Foundation
import SwiftUI


struct DetailsTableRow: View {
    let context: Composition
    let columns: [TableColumn]
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        TableRowSurface(selected: selected, action: onSelect) {
            TableCell(column: columns[0]) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Boundary.with(context.boundary, { $0 })?.name ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.86))
                            .lineLimit(1)

                        Text(Boundary.with(context.boundary, { $0 })?.name ?? "")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            TableCell(column: columns[1]) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Boundary.with(context.boundary, { $0 })?.name ?? "")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.8))
                        .lineLimit(1)

                    Text(Boundary.with(context.boundary, { $0 })?.name ?? "")
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

struct DetailsPanel: Panel {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        ScrollView {
            Color.clear.frame(height: 90)
            Constructor.build(
                agency.studio.content,
                DetailMapper.params(agency),
                DetailMapper.closures(agency)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
