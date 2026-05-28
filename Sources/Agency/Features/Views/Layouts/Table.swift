import SwiftUI
import AgencyRuntime

struct TableItemIcon: View {
    let item: ItemParams

    var body: some View {
        HStack(spacing: 8) {
            ComponentIcon(item: item, size: .table)

            Text(item.name)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.primary.opacity(0.9))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }
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

struct TableCell<Content: View>: View {
    let column: ColumnParams
    @ViewBuilder let content: () -> Content

    init(column: ColumnParams, @ViewBuilder content: @escaping () -> Content) {
        self.column = column
        self.content = content
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: column.alignment.frameAlignment)
            .frame(width: column.width, alignment: column.alignment.frameAlignment)
    }
}

struct TableHeader: View {
    let columns: [ColumnParams]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                TableCell(column: column) {
                    Text(column.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.primary.opacity(0.06)).frame(height: 1)
        }
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

struct TableRow: View {
    @State private var isHovered = false
    let item: ItemParams
    let columns: [ColumnParams]
    let closures: Closures
    let expanded: Bool
    let selected: Bool
    let selectAction: (() -> Void)?
    let openAction: (() -> Void)?
    let detail: AnyView?
    let cellContent: ((ColumnParams, ItemParams) -> AnyView?)?

    init(
        item: ItemParams,
        columns: [ColumnParams],
        closures: Closures,
        expanded: Bool = false,
        detail: AnyView? = nil,
        cellContent: ((ColumnParams, ItemParams) -> AnyView?)? = nil
    ) {
        self.item = item
        self.columns = columns
        self.closures = closures
        self.expanded = expanded
        self.selected = closures.selected?(item) ?? false
        self.selectAction = closures.onSelect.map { onSelect in { onSelect(item) } }
        self.openAction = closures.onOpen.map { onOpen in { onOpen(item) } }
        self.detail = detail
        self.cellContent = cellContent
    }

    private var row: some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                TableCell(column: column) {
                    cell(column, item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minHeight: 44)
        .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selected ? Color.white.opacity(0.03) : isHovered ? Color.white.opacity(0.03) : Color.white.opacity(0))
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    var body: some View {
        VStack(spacing: 0) {
            row
                .gesture(
                    TapGesture(count: 2).onEnded { openAction?() }
                        .exclusively(before: TapGesture(count: 1).onEnded { selectAction?() })
                )
                .onHover { isHovered = $0 }

            if expanded, let detail {
                detail
            }
        }
    }

    @ViewBuilder private func cell(_ column: ColumnParams, _ item: ItemParams) -> some View {
        if let custom = cellContent?(column, item) {
            custom
        } else {
            defaultCell(column.value, item)
        }
    }

    @ViewBuilder private func defaultCell(_ value: ColumnParams.ColumnValue, _ item: ItemParams) -> some View {
        switch value {
        case .primary:
            TableItemIcon(item: item)
        case .name:
            text(item.name, weight: .semibold)
        case .description:
            text(item.description ?? "")
        case .child(let i):
            if item.items.indices.contains(i) { summary(item.items[i]) }
        case .tags:
            text(item.tags.joined(separator: ", "))
        case .badge:
            if let badge = item.badges.first { TableBadge(title: badge.label, color: badge.tint) }
        case .badges:
            HStack(spacing: 6) {
                ForEach(item.badges) { TableBadge(title: $0.label, color: $0.tint) }
            }
        case .count:
            text(item.count.map(String.init) ?? "")
        case .text(let value):
            text(value)
        }
    }

    private func text(_ value: String, weight: Font.Weight = .regular) -> some View {
        Text(value)
            .font(.system(size: 12, weight: weight))
            .foregroundStyle(weight == .regular ? Color.secondary : Color.primary.opacity(0.9))
            .lineLimit(1)
    }

    private func summary(_ item: ItemParams) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            text(item.name, weight: .semibold)
            if let description = item.description, !description.isEmpty { text(description) }
        }
    }
}

struct TableLayout: View {
    let section: ListParams
    let columns: [ColumnParams]
    let closures: Closures
    let expanded: (ItemParams) -> Bool
    let detail: (ItemParams) -> AnyView?
    let cellContent: ((ColumnParams, ItemParams) -> AnyView?)?

    init(
        section: ListParams,
        columns: [ColumnParams],
        closures: Closures,
        expanded: ((ItemParams) -> Bool)? = nil,
        detail: ((ItemParams) -> AnyView?)? = nil,
        cellContent: ((ColumnParams, ItemParams) -> AnyView?)? = nil
    ) {
        self.section = section
        self.columns = columns
        self.closures = closures
        self.expanded = expanded ?? closures.tableExpanded ?? { _ in false }
        self.detail = detail ?? closures.tableDetail ?? { _ in nil }
        self.cellContent = cellContent ?? closures.tableCell
    }

    var body: some View { tableContent }

    private var tableContent: some View {
        VStack(spacing: 0) {
            if !columns.isEmpty { TableHeader(columns: columns) }

            VStack(spacing: 0) {
                if section.header || section.footnote != nil {
                    TableSectionHeader(title: section.header ? section.name : nil, detail: section.footnote)
                }
                VStack {
                    ForEach(section.items) { item in
                        TableRow(
                            item: item,
                            columns: columns,
                            closures: closures,
                            expanded: expanded(item),
                            detail: detail(item),
                            cellContent: cellContent
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
