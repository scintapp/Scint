import SwiftUI


private enum GridItemRole: Equatable {
    case item
    case space
    case sheet(Reference)

    var isSheet: Bool {
        if case .sheet = self { return true }
        return false
    }

    var reference: Reference? {
        if case .sheet(let ref) = self { return ref }
        return nil
    }

    init(_ ref: Reference?) {
        switch ref?.type {
            case is Space.Type: self = .space
            case is Sheet.Type: self = ref.map(Self.sheet) ?? .item
            default: self = .item
        }
    }
}

private struct GridItemRoleKey: ContainerValueKey {
    static let defaultValue: GridItemRole = .item
}

private extension ContainerValues {
    var gridItem: GridItemRole {
        get { self[GridItemRoleKey.self] }
        set { self[GridItemRoleKey.self] = newValue }
    }
}

extension View {
    func gridItem(_ ref: Reference?) -> some View {
        containerValue(\.gridItem, GridItemRole(ref))
    }
}



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
                Button {
                    onChange(item)
                } label: {
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

struct GroupHeader: View {
    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    let ref: Reference?
    let title: String
    let description: String

    init(ref: Reference? = nil, title: String, description: String) {
        self.ref = ref
        self.title = title
        self.description = description
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                if let ref {
                    Iconography.icon(for: ref, size: 18)
                        .padding(.trailing, 6)
                }
                Text(title)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.9))
            }
            .frame(maxHeight: 64)
            .padding(.vertical, 12)
            Divider()
            Text(description.isEmpty ? "No description." : description)
                .padding(.bottom, 12)
                .font(.system(size: 12))
                .foregroundStyle(
                    description.isEmpty ?
                    Design.Foreground.tertiary :
                        Design.Foreground.secondary
                )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(shape.fill(.primary.opacity(0.08)))
        .overlay(shape.stroke(.primary.opacity(0.03), lineWidth: 1))
    }
}

struct GroupRow<Leading: View, Trailing: View>: View {
    let label: String
    let description: String
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    init(
        label: String,
        description: String = "",
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.label = label
        self.description = description
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center) {
            leading
                .frame(width: 38, height: description.isEmpty ? 38 : 50)
                .foregroundStyle(.tertiary)
                .font(.system(size: 15, weight: .medium))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.88))
                    .lineLimit(1)

                if !description.isEmpty {
                    Text(description)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.72))
                        .lineLimit(1)
                }
            }
            .frame(height: description.isEmpty ? 38 : 50, alignment: .center)

            Spacer()

            trailing
                .frame(height: description.isEmpty ? 38 : 50)
                .labelsHidden()
                .controlSize(.small)
        }
        .frame(height: description.isEmpty ? 38 : 50, alignment: .center)
        .padding(.horizontal, 8)
    }
}

struct GroupLayout<Content: View>: View {
    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
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

            VStack(spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(shape.fill(.primary.opacity(0.08)))
            .overlay(shape.stroke(.primary.opacity(0.03), lineWidth: 1))

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
