import SwiftUI


typealias GroupRow<Leading: View, Trailing: View> = RowLayout<Leading, Trailing>

extension View { func gridItem(_ ref: Reference?) -> some View { containerValue(\.gridItem, GridItemRole(ref)) } }

struct GroupDivider: View { var body: some View { Divider().padding(.horizontal, 8) } }

struct GroupToggle: View {
    let isOn: Bool
    let onChange: () -> Void

    var body: some View {
        Toggle("", isOn: Binding(get: { isOn }, set: { _ in onChange() }))
            .toggleStyle(.switch)
            .scaleEffect(0.8)
    }
}

struct GroupPicker: View {
    let value: String
    let items: [ItemParams]
    let onChange: (ItemParams) -> Void

    var body: some View {
        let selected = items.first { ($0.value ?? "") == value }!

        SwiftUI.Menu {
            ForEach(items) { item in
                Button { onChange(item) } label: {
                    Text(item.name)
                    if item == selected { Image(systemName: "checkmark") }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selected.name)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(.quaternary, in: Circle())
            }
            .font(.system(size: 12))
            .frame(width: 132, alignment: .trailing)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}

struct GroupField: View {
    let value: String
    let onChange: (String) -> Void

    var body: some View {
        TextField("", text: Binding(get: { value }, set: onChange))
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.plain)
            .frame(width: 112)
    }
}

struct GroupDate: View {
    let value: String
    let onChange: (String) -> Void

    private var selection: Binding<Date> {
        Binding(
            get: { Value.formatter.date(from: value) ?? .now },
            set: { onChange(Value.formatter.string(from: $0)) }
        )
    }

    var body: some View {
        DatePicker("", selection: selection, displayedComponents: [.date, .hourAndMinute])
            .datePickerStyle(.compact)
            .labelsHidden()
    }
}

struct GroupRemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

struct GroupCountButton: View {
    let count: Int?
    var label = "Load"
    let onLoad: () -> Void

    var body: some View {
        HStack {
            if let count {
                Text(count == 0 ? "None" : count == 1 ? "1 Loaded" : "\(count) Loaded")
                    .font(.system(size: 12))
                    .foregroundStyle(count == 0 ? .tertiary : .secondary)
            }
            Button(label, action: onLoad)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct RowLayout<Leading: View, Trailing: View>: View {
    let title: Text
    let detail: Text?
    let detailLineLimit: Int
    let spacing: CGFloat?
    let spacerMinLength: CGFloat?
    let groupHeight: CGFloat?
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    init(
        title: Text,
        detail: Text? = nil,
        detailLineLimit: Int = 1,
        spacing: CGFloat? = nil,
        spacerMinLength: CGFloat? = nil,
        groupHeight: CGFloat? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.detail = detail
        self.detailLineLimit = detailLineLimit
        self.spacing = spacing
        self.spacerMinLength = spacerMinLength
        self.groupHeight = groupHeight
        self.leading = leading()
        self.trailing = trailing()
    }

    init(
        label: String,
        description: String = "",
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            title: Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary.opacity(0.88)),
            detail: description.isEmpty ? nil : Text(description)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary.opacity(0.72)),
            groupHeight: description.isEmpty ? 38 : 50,
            leading: leading,
            trailing: trailing
        )
    }

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            if let groupHeight {
                leading
                    .frame(width: 38, height: groupHeight)
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 15, weight: .medium))
            } else {
                leading
            }

            VStack(alignment: .leading, spacing: Style.Spacing.xs) {
                title.lineLimit(1)
                if let detail { detail.lineLimit(detailLineLimit) }
            }
            .frame(height: groupHeight, alignment: .center)

            Spacer(minLength: spacerMinLength)

            if let groupHeight {
                trailing
                    .frame(height: groupHeight)
                    .labelsHidden()
                    .controlSize(.small)
            } else {
                trailing
            }
        }
        .frame(height: groupHeight, alignment: .center)
        .padding(.horizontal, groupHeight == nil ? 0 : 8)
    }
}

struct GroupLayout<Content: View>: View {
    let title: String
    let footer: String?
    @ViewBuilder let content: () -> Content

    init(title: String, footer: String?, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack {
            Text(title)
                .padding(.leading, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.75))

            VStack(spacing: 0) { content() }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(Style.Shape.medium.fill(Style.Background.group))
                .overlay(Style.Shape.medium.stroke(Style.Border.group, lineWidth: 0.5))

            if let footer {
                Text(footer)
                    .padding(.leading, 4)
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
    }
}
