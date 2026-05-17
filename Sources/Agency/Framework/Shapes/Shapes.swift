import AgencyRuntime
import SwiftUI


struct ItemCard: View {
    let item: ItemParams
    let settings: Controls
    let shape: RoundedRectangle = RoundedRectangle(cornerRadius: 24)

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.bottom, 4)

                if let description = item.description {
                    Text(description)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if !item.badges.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(item.badges) { badge in Badge(icon: badge.icon, label: badge.label, count: badge.count, color: badge.tint, glass: false) }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .frame(width: 160, height: 160, alignment: .topLeading)
        .contentShape(shape)
        .background { shape.fill(Design.Background.panels) }
        .overlay { shape.stroke(lineWidth: 1).fill(.primary.opacity(0.1)) }
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture(count: 2) { settings.onOpen?(item) }
        .onTapGesture { settings.onSelect?(item) }
    }
}

struct ItemRow<Content: View>: View {
    let name: String
    let accessory: AnyView?
    let trailingImage: String?
    let count: Int?
    let indent: CGFloat
    let isHovered: Bool
    let selected: Bool
    let isEditing: Bool
    let editText: Binding<String>?
    let onCommitEdit: (() -> Void)?
    let content: Content

    init(
        name: String, accessory: AnyView? = nil, trailingImage: String? = nil, count: Int? = nil,
        indent: CGFloat = 0, isHovered: Bool = false, selected: Bool = false, isEditing: Bool = false,
        editText: Binding<String>? = nil, onCommitEdit: (() -> Void)? = nil,
        @ViewBuilder leading: () -> Content) {

        self.name = name
        self.accessory = accessory
        self.count = count
        self.indent = indent
        self.isHovered = isHovered
        self.selected = selected
        self.isEditing = isEditing
        self.editText = editText
        self.onCommitEdit = onCommitEdit
        self.trailingImage = trailingImage
        self.content = leading()
    }

    var body: some View {
        HStack {
            Color.clear.frame(width: indent)
            content

            if isEditing, let editText {
                TextField("Name", text: editText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .onSubmit { onCommitEdit?() }
            } else {
                Text(name)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            if let accessory { accessory.padding(.trailing, 8) }
            if let trailingImage { Image(systemName: trailingImage).font(.system(size: 12)) }

            if let count {
                Text("\(count)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 24)
        .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Color.secondary.opacity(0.1) : .clear))
        .foregroundStyle(selected ? Color.gray : .primary)
        .contentShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct Block: View {
    let title: String
    let text: String
    let footnote: String

    var body: some View {
        VStack {
            if !title.isEmpty {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.75))
            }

            Group {
                if text.isEmpty {
                    Text("Empty")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(text)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.primary.opacity(0.08))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.primary.opacity(0.03), lineWidth: 1)
            }

            if !footnote.isEmpty {
                Text(footnote)
                    .padding(.leading, 4)
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

